require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @analysis = create_analysis(user: @user, status: "completed")
  end

  test "is valid with role user" do
    msg = ChatMessage.new(analysis: @analysis, role: "user", content: "Hello")
    assert msg.valid?
  end

  test "is valid with role assistant" do
    msg = ChatMessage.new(analysis: @analysis, role: "assistant", content: "Hello back")
    assert msg.valid?
  end

  test "rejects invalid role" do
    msg = ChatMessage.new(analysis: @analysis, role: "admin", content: "Hello")
    assert_not msg.valid?
    assert msg.errors[:role].any?
  end

  test "requires content" do
    msg = ChatMessage.new(analysis: @analysis, role: "user", content: "")
    assert_not msg.valid?
    assert msg.errors[:content].any?
  end

  test "requires analysis" do
    msg = ChatMessage.new(role: "user", content: "Hello")
    assert_not msg.valid?
  end
end
