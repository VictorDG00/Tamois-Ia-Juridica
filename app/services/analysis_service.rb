class AnalysisService
  def initialize(analysis)
    @analysis = analysis
  end

  def run
    @analysis.update!(status: "processing")

    file_path = ActiveStorage::Blob.service.path_for(@analysis.docx_file.key)
    text = DocxExtractor.extract(file_path)
    raise ArgumentError, "Documento vazio ou ilegível." if text.blank?

    @analysis.update!(original_text: text)

    client = DeepseekClient.new(
      model: @analysis.analysis_mode == "deep" ? "deepseek-reasoner" : "deepseek-chat"
    )

    # Cada seção é salva individualmente — a UI acende os checkpoints em tempo real.
    entities = client.analyze_section(text, :entities)
    @analysis.update!(entities_json: entities.to_json)

    orthography = client.analyze_section(text, :orthography)
    @analysis.update!(orthography_json: orthography.to_json)

    writing = client.analyze_section(text, :writing)
    @analysis.update!(writing_suggestions_json: writing.to_json)

    insights = client.analyze_section(text, :insights)
    @analysis.update!(legal_insights_json: insights.to_json, status: "completed")

  rescue => e
    @analysis.update!(status: "failed")
    Rails.logger.error("AnalysisService error: #{e.class} — #{e.message}")
    raise
  end
end
