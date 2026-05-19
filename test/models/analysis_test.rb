require "test_helper"

class AnalysisTest < ActiveSupport::TestCase
  def setup
    @user = create_user
  end

  test "is valid with required fields" do
    analysis = Analysis.new(
      user: @user,
      filename: "test.docx",
      status: "pending",
      analysis_mode: "fast"
    )
    assert analysis.valid?
  end

  test "requires filename" do
    analysis = Analysis.new(user: @user, status: "pending", analysis_mode: "fast")
    assert_not analysis.valid?
    assert analysis.errors[:filename].any?
  end

  test "rejects invalid status" do
    analysis = Analysis.new(user: @user, filename: "test.docx", status: "invalid", analysis_mode: "fast")
    assert_not analysis.valid?
  end

  test "rejects invalid analysis_mode" do
    analysis = Analysis.new(user: @user, filename: "test.docx", status: "pending", analysis_mode: "turbo")
    assert_not analysis.valid?
  end

  test "orthography parses JSON safely" do
    analysis = create_analysis(user: @user)
    analysis.update_column(:orthography_json, '[{"original":"rescição","suggestion":"rescisão","reason":"Grafia correta"}]')
    result = analysis.orthography
    assert_equal 1, result.length
    assert_equal "rescição", result.first["original"]
  end

  test "orthography returns empty array on nil" do
    analysis = create_analysis(user: @user)
    analysis.update_column(:orthography_json, nil)
    assert_equal [], analysis.orthography
  end

  test "orthography returns empty array on invalid JSON" do
    analysis = create_analysis(user: @user)
    analysis.update_column(:orthography_json, "invalid json {{{")
    assert_equal [], analysis.orthography
  end

  test "legal_insights parses JSON correctly" do
    analysis = create_analysis(user: @user)
    insights = [{ "topic" => "Rescisão", "insight" => "Risco alto.", "risk_level" => "high", "paragraph_id" => 2 }]
    analysis.update_column(:legal_insights_json, insights.to_json)
    result = analysis.legal_insights
    assert_equal 1, result.length
    assert_equal "high", result.first["risk_level"]
  end

  test "completed? returns true when status is completed" do
    analysis = create_analysis(user: @user, status: "completed")
    assert analysis.completed?
    assert_not analysis.failed?
    assert_not analysis.processing?
  end

  test "failed? returns true when status is failed" do
    analysis = create_analysis(user: @user, status: "failed")
    assert analysis.failed?
    assert_not analysis.completed?
  end

  test "sets default status to pending" do
    analysis = Analysis.new(user: @user, filename: "test.docx", analysis_mode: "fast")
    analysis.valid?
    assert_equal "pending", analysis.status
  end

  test "sets default mode to fast" do
    analysis = Analysis.new(user: @user, filename: "test.docx")
    analysis.valid?
    assert_equal "fast", analysis.analysis_mode
  end

  test "belongs to user" do
    analysis = create_analysis(user: @user)
    assert_equal @user, analysis.user
  end

  test "has many chat_messages" do
    analysis = create_analysis(user: @user, status: "completed")
    ChatMessage.create!(analysis: analysis, role: "user", content: "Teste")
    assert_equal 1, analysis.chat_messages.count
  end
end
