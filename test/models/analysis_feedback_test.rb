require "test_helper"

class AnalysisFeedbackTest < ActiveSupport::TestCase
  def setup
    @user     = create_user
    @analysis = create_analysis(user: @user, status: "completed")
    @analysis.update!(orthography_json: [{ "original" => "rescição", "suggestion" => "rescisão", "reason" => "r" }].to_json)
  end

  test "is valid with required fields" do
    fb = AnalysisFeedback.new(analysis: @analysis, user: @user,
                              section: "orthography", item_index: 0, verdict: "incorrect")
    assert fb.valid?
  end

  test "rejects invalid section" do
    fb = AnalysisFeedback.new(analysis: @analysis, user: @user,
                              section: "typos", item_index: 0, verdict: "incorrect")
    assert_not fb.valid?
  end

  test "rejects invalid verdict" do
    fb = AnalysisFeedback.new(analysis: @analysis, user: @user,
                              section: "orthography", item_index: 0, verdict: "great")
    assert_not fb.valid?
  end

  test "rejects negative item_index" do
    fb = AnalysisFeedback.new(analysis: @analysis, user: @user,
                              section: "orthography", item_index: -1, verdict: "incorrect")
    assert_not fb.valid?
  end

  test "item_data parses snapshot correctly" do
    fb = AnalysisFeedback.create!(analysis: @analysis, user: @user,
                                  section: "orthography", item_index: 0, verdict: "incorrect",
                                  item_snapshot: { "original" => "rescição" }.to_json)
    assert_equal "rescição", fb.item_data["original"]
  end

  test "item_data returns empty hash on invalid JSON" do
    fb = AnalysisFeedback.new(item_snapshot: "{{invalid")
    assert_equal({}, fb.item_data)
  end

  test "section_label returns Portuguese label" do
    fb = AnalysisFeedback.new(section: "insights")
    assert_equal "Insights jurídicos", fb.section_label
  end

  test "analysis has_many feedbacks destroyed with analysis" do
    AnalysisFeedback.create!(analysis: @analysis, user: @user,
                             section: "orthography", item_index: 0, verdict: "incorrect")
    assert_difference "AnalysisFeedback.count", -1 do
      @analysis.destroy
    end
  end
end
