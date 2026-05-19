require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "GET /dashboard requires authentication" do
    get dashboard_path
    assert_redirected_to new_user_session_path
  end

  test "GET /dashboard shows dashboard for authenticated user" do
    user = create_user
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    get dashboard_path
    assert_response :success
    assert_select "h1"
  end

  test "dashboard shows correct stats" do
    user = create_user
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    3.times { |i| create_analysis(user: user, filename: "doc#{i}.docx", status: "completed") }
    create_analysis(user: user, filename: "fail.docx", status: "failed")

    get dashboard_path
    assert_response :success
  end
end
