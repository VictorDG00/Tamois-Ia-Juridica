require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET / renders landing page for guests" do
    get root_path
    assert_response :success
    assert_select "h1"
  end

  test "GET / redirects signed-in users to dashboard" do
    user = create_user
    sign_in(user)
    get root_path
    assert_redirected_to dashboard_path
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
