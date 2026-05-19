require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user     = create_user
    @analysis = create_analysis(user: @user, status: "completed")
    @analysis.update!(
      orthography_json: [{ "original" => "rescição", "suggestion" => "rescisão", "reason" => "r" }].to_json,
      writing_suggestions_json: [].to_json,
      legal_insights_json: [].to_json
    )
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "GET /feedbacks requires authentication" do
    delete destroy_user_session_path
    get feedbacks_path
    assert_redirected_to new_user_session_path
  end

  test "GET /feedbacks shows page for authenticated user" do
    get feedbacks_path
    assert_response :success
  end

  test "POST feedback creates record and redirects" do
    assert_difference "AnalysisFeedback.count", 1 do
      post analysis_feedbacks_path(@analysis),
           params: { section: "orthography", item_index: 0 }
    end
    assert_redirected_to analysis_path(@analysis, anchor: "feedback-orthography-0")
  end

  test "POST feedback stores correct section and snapshot" do
    post analysis_feedbacks_path(@analysis),
         params: { section: "orthography", item_index: 0 }
    fb = AnalysisFeedback.last
    assert_equal "orthography", fb.section
    assert_equal 0, fb.item_index
    assert_equal "incorrect", fb.verdict
    assert_includes fb.item_snapshot, "rescição"
  end

  test "POST feedback rejects access to another user's analysis" do
    other          = create_user(email: "other@example.com")
    other_analysis = create_analysis(user: other)
    assert_no_difference "AnalysisFeedback.count" do
      post analysis_feedbacks_path(other_analysis),
           params: { section: "orthography", item_index: 0 }
    end
    assert_redirected_to analyses_path
  end
end
