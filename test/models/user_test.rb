require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with name, email and password" do
    user = User.new(name: "João Silva", email: "joao@example.com", password: "password123", password_confirmation: "password123")
    assert user.valid?
  end

  test "requires name" do
    user = User.new(email: "test@example.com", password: "password123", password_confirmation: "password123")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "requires email" do
    user = User.new(name: "Test", password: "password123", password_confirmation: "password123")
    assert_not user.valid?
  end

  test "name must be at least 2 characters" do
    user = User.new(name: "A", email: "test@example.com", password: "password123", password_confirmation: "password123")
    assert_not user.valid?
    assert user.errors[:name].any?
  end

  test "analyses_used returns count of associated analyses" do
    user = create_user
    assert_equal 0, user.analyses_used
    create_analysis(user: user)
    assert_equal 1, user.reload.analyses_used
  end

  test "has many analyses" do
    user = create_user
    3.times { |i| create_analysis(user: user, filename: "doc#{i}.docx") }
    assert_equal 3, user.analyses.count
  end
end
