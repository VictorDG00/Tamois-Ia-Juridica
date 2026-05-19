class FeedbacksController < ApplicationController
  before_action :authenticate_user!

  def create
    analysis = current_user.analyses.find(params[:analysis_id])

    section     = params[:section].to_s
    item_index  = params[:item_index].to_i
    comment     = params[:comment].to_s.strip

    item_snapshot = case section
    when "orthography" then analysis.orthography[item_index]
    when "writing"     then analysis.writing_suggestions[item_index]
    when "insights"    then analysis.legal_insights[item_index]
    when "entities"    then analysis.entities
    end

    feedback = AnalysisFeedback.create!(
      analysis:      analysis,
      user:          current_user,
      section:       section,
      item_index:    item_index,
      verdict:       "incorrect",
      comment:       comment.presence,
      item_snapshot: item_snapshot.to_json
    )

    respond_to do |format|
      format.html { redirect_to analysis_path(analysis, anchor: "feedback-#{section}-#{item_index}"),
                    notice: "Feedback registrado. Obrigado!" }
      format.json { render json: { id: feedback.id }, status: :created }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to analyses_path, alert: "Análise não encontrada."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: analyses_path, alert: "Erro ao registrar feedback: #{e.message}"
  end

  def index
    @feedbacks = AnalysisFeedback
      .joins(:analysis)
      .where(analyses: { user_id: current_user.id })
      .includes(:analysis, :user)
      .order(created_at: :desc)

    @by_section = @feedbacks.group_by(&:section)
    @total      = @feedbacks.count
  end
end
