class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_analysis

  def show
    @messages = @analysis.chat_messages.order(:created_at)
  end

  def create
    user_content = params[:message].to_s.strip

    if user_content.blank?
      redirect_to analysis_chat_path(@analysis), alert: "Mensagem não pode ser vazia."
      return
    end

    @analysis.chat_messages.create!(role: "user", content: user_content)

    messages = build_chat_messages(@analysis, user_content)
    client = DeepseekClient.new

    begin
      reply = client.chat(messages)
      @analysis.chat_messages.create!(role: "assistant", content: reply)
    rescue DeepseekClient::ProviderError => e
      @analysis.chat_messages.create!(
        role: "assistant",
        content: "Erro ao processar sua pergunta. Tente novamente."
      )
      Rails.logger.error("Chat error: #{e.message}")
    end

    redirect_to analysis_chat_path(@analysis)
  end

  private

  def set_analysis
    @analysis = current_user.analyses.find(params[:analysis_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to analyses_path, alert: "Análise não encontrada."
  end

  def build_chat_messages(analysis, user_question)
    system_message = {
      role: "system",
      content: <<~SYS
        Você é Tamois, um assistente jurídico especializado em direito brasileiro.
        O usuário está revisando o seguinte documento jurídico. Responda perguntas sobre o conteúdo,
        riscos identificados e sugestões de melhoria. Seja objetivo, preciso e cite trechos quando relevante.

        Resumo da análise:
        - #{analysis.orthography.length} correções ortográficas identificadas
        - #{analysis.writing_suggestions.length} sugestões de redação
        - #{analysis.legal_insights.length} insights jurídicos (#{analysis.legal_insights.count { |i| i["risk_level"] == "high" }} de alto risco)

        Trecho do documento:
        #{analysis.original_text.to_s[0, 4000]}
      SYS
    }

    history = analysis.chat_messages.order(:created_at).last(10).map do |msg|
      { role: msg.role, content: msg.content }
    end

    [system_message] + history
  end
end
