class AnalysisService
  def initialize(analysis)
    @analysis = analysis
  end

  def run
    @analysis.update!(status: "processing")

    file_path = ActiveStorage::Blob.service.path_for(@analysis.docx_file.key)
    text = DocxExtractor.extract(file_path)
    raise ArgumentError, "Documento vazio ou ilegível." if text.blank?

    client = DeepseekClient.new(
      model: @analysis.analysis_mode == "deep" ? "deepseek-reasoner" : "deepseek-chat"
    )
    result = client.analyze(text)

    @analysis.update!(
      original_text: text,
      orthography_json: result["orthography"].to_json,
      writing_suggestions_json: result["writing_suggestions"].to_json,
      legal_insights_json: result["legal_insights"].to_json,
      status: "completed"
    )

    result
  rescue => e
    @analysis.update!(status: "failed")
    Rails.logger.error("AnalysisService error: #{e.class} — #{e.message}")
    raise
  end
end
