require "test_helper"

class AnalysesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    sign_in(@user)
  end

  test "GET /analyses requires authentication" do
    sign_out
    get analyses_path
    assert_redirected_to new_user_session_path
  end

  test "GET /analyses shows index for signed-in user" do
    get analyses_path
    assert_response :success
  end

  test "GET /analyses/new shows upload form" do
    get new_analysis_path
    assert_response :success
  end

  test "GET /analyses/:id shows analysis" do
    analysis = create_analysis(user: @user, status: "completed")
    get analysis_path(analysis)
    assert_response :success
  end

  test "GET /analyses/:id denies access to other user's analysis" do
    other_user = create_user(email: "other@example.com")
    analysis = create_analysis(user: other_user)
    get analysis_path(analysis)
    assert_redirected_to analyses_path
  end

  test "POST /analyses rejects request without file" do
    post analyses_path, params: { analysis: { analysis_mode: "fast" } }
    assert_redirected_to new_analysis_path
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end

  def sign_out
    delete destroy_user_session_path
  end
end
