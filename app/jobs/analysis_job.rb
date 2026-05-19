class AnalysisJob < ApplicationJob
  queue_as :default

  def perform(analysis_id)
    analysis = Analysis.find(analysis_id)
    AnalysisService.new(analysis).run
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("AnalysisJob: análise #{analysis_id} não encontrada")
  rescue => e
    Rails.logger.error("AnalysisJob falhou para análise #{analysis_id}: #{e.class} — #{e.message}")
  end
end
