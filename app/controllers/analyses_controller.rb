class AnalysesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_analysis, only: %i[show download]

  def index
    @analyses = current_user.analyses.order(created_at: :desc)
  end

  def new
    @analysis = Analysis.new
  end

  def create
    file = params[:analysis][:docx_file]
    mode = params[:analysis][:analysis_mode].presence_in(%w[fast deep]) || "fast"

    unless file
      flash[:alert] = "Por favor, envie um arquivo DOCX."
      return redirect_to new_analysis_path
    end

    unless file.content_type.in?(%w[
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/octet-stream
    ]) || file.original_filename.ends_with?(".docx")
      flash[:alert] = "O arquivo deve estar no formato DOCX."
      return redirect_to new_analysis_path
    end

    @analysis = current_user.analyses.build(
      filename: file.original_filename,
      analysis_mode: mode,
      status: "pending"
    )
    @analysis.docx_file.attach(file)

    if @analysis.save
      AnalysisJob.perform_later(@analysis.id)
      redirect_to @analysis, notice: "Documento enviado. A análise está sendo processada…"
    else
      flash[:alert] = "Erro ao salvar o arquivo."
      redirect_to new_analysis_path
    end
  end

  def show
  end

  def download
    unless @analysis.completed?
      return redirect_to @analysis, alert: "A análise ainda não foi concluída."
    end

    docx_bytes = DocxAnnotator.new(@analysis).generate
    filename   = "tamois_#{@analysis.filename.delete_suffix(".docx")}_anotado.docx"

    send_data docx_bytes,
      filename:    filename,
      type:        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      disposition: "attachment"
  rescue => e
    Rails.logger.error("DocxAnnotator error: #{e.class} — #{e.message}")
    redirect_to @analysis, alert: "Erro ao gerar o documento anotado. Tente novamente."
  end

  private

  def set_analysis
    @analysis = current_user.analyses.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to analyses_path, alert: "Análise não encontrada."
  end
end
