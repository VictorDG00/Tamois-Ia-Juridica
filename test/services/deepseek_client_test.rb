require "test_helper"

class DeepseekClientTest < ActiveSupport::TestCase
  def setup
    @client = DeepseekClient.new(api_key: "test_key")
  end

  test "raises ProviderError when api_key is blank" do
    client = DeepseekClient.new(api_key: "")
    assert_raises(DeepseekClient::ProviderError) { client.analyze("texto") }
  end

  test "normalize_orthography filters invalid items" do
    result = @client.send(:normalize_orthography, [
      { "original" => "rescição", "suggestion" => "rescisão", "reason" => "ok" },
      { "original" => "", "suggestion" => "algo" },
      { "original" => "x" },
      "not a hash"
    ])
    assert_equal 1, result.length
    assert_equal "rescição", result.first["original"]
  end

  test "normalize_writing filters invalid items" do
    result = @client.send(:normalize_writing, [
      { "excerpt" => "trecho", "suggestion" => "melhorado", "reason" => "ok" },
      { "excerpt" => "", "suggestion" => "algo" }
    ])
    assert_equal 1, result.length
  end

  test "normalize_insights sets medium as default for unknown risk" do
    result = @client.send(:normalize_insights, [
      { "topic" => "X", "insight" => "Y", "risk_level" => "extreme", "paragraph_id" => 0 }
    ])
    assert_equal "medium", result.first["risk_level"]
  end

  test "normalize_insights appends disclaimer" do
    result = @client.send(:normalize_insights, [
      { "topic" => "T", "insight" => "Risco de nulidade.", "risk_level" => "high", "paragraph_id" => 1 }
    ])
    assert_includes result.first["insight"], DeepseekClient::DISCLAIMER
  end

  test "normalize retorna todos os insights sem limite" do
    items = 20.times.map { |i| { "topic" => "T#{i}", "insight" => "I#{i}", "risk_level" => "low", "paragraph_id" => i } }
    result = @client.send(:normalize, {
      "orthography" => [],
      "writing_suggestions" => [],
      "legal_insights" => items
    })
    assert_equal 20, result["legal_insights"].length
  end

  test "normalize_insights caps field length" do
    long_topic = "A" * 500
    result = @client.send(:normalize_insights, [
      { "topic" => long_topic, "insight" => "I", "risk_level" => "low", "paragraph_id" => 0 }
    ])
    assert result.first["topic"].length <= DeepseekClient::MAX_FIELD_LENGTH
  end

  test "strip_markdown removes json fences" do
    text = "```json\n{\"key\":\"val\"}\n```"
    result = @client.send(:strip_markdown, text)
    assert_equal '{"key":"val"}', result
  end

  test "strip_markdown leaves plain JSON unchanged" do
    text = '{"key":"val"}'
    assert_equal text, @client.send(:strip_markdown, text)
  end

  test "extract_json_object extracts embedded JSON" do
    text = 'some prefix {"key":"val"} trailing'
    result = @client.send(:extract_json_object, text)
    assert_equal '{"key":"val"}', result
  end

  test "extract_json_object returns nil when no JSON found" do
    result = @client.send(:extract_json_object, "plain text without braces")
    assert_nil result
  end

  test "parse_paragraph_id handles integer" do
    assert_equal 5, @client.send(:parse_paragraph_id, 5)
  end

  test "parse_paragraph_id handles float string" do
    assert_equal 3, @client.send(:parse_paragraph_id, "3.0")
  end

  test "parse_paragraph_id returns -1 for nil" do
    assert_equal -1, @client.send(:parse_paragraph_id, nil)
  end

  test "parse_paragraph_id returns -1 for negative" do
    assert_equal -1, @client.send(:parse_paragraph_id, -5)
  end

  test "parse_paragraph_id returns -1 for non-numeric" do
    assert_equal -1, @client.send(:parse_paragraph_id, "abc")
  end

  test "normalize validates complete contract" do
    payload = {
      "orthography" => [{ "original" => "a", "suggestion" => "b", "reason" => "r" }],
      "writing_suggestions" => [{ "excerpt" => "e", "suggestion" => "s", "reason" => "r" }],
      "legal_insights" => [{ "topic" => "t", "insight" => "i", "risk_level" => "high", "paragraph_id" => 0 }]
    }
    result = @client.send(:normalize, payload)
    assert_equal 1, result["orthography"].length
    assert_equal 1, result["writing_suggestions"].length
    assert_equal 1, result["legal_insights"].length
  end
end
