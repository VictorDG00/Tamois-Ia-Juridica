require "test_helper"
require "yaml"
require_relative "fixtures/contrato_fixture"

# Testes de regressão do motor de análise contra o DeepSeek real.
#
# QUANDO RODAR: a cada alteração de prompt, temperatura ou lógica de normalização.
# COMO RODAR:   bundle exec rails test test/evals/  OU  bin/eval
#
# Chama a API DeepSeek 3 vezes (uma por seção) e verifica que os erros conhecidos
# do contrato fixture são detectados. Skipa automaticamente sem DEEPSEEK_API_KEY.
class AnalysisEvalTest < ActiveSupport::TestCase
  FINDINGS = YAML.load_file(
    File.expand_path("fixtures/expected_findings.yml", __dir__)
  ).freeze

  # Memoização no nível da classe (uma chamada por seção por suite)
  @eval_results = nil

  def self.eval_results
    return @eval_results if @eval_results

    key = ENV.fetch("DEEPSEEK_API_KEY", "")
    return nil if key.blank? || key.start_with?("sua_")

    text   = ContratoFixture.plain_text
    raise "Fixture retornou texto vazio — verifique contrato_fixture.rb" if text.blank?

    client = DeepseekClient.new(api_key: key, model: "deepseek-chat")

    @eval_results = {
      orthography: client.analyze_section(text, :orthography),
      writing:     client.analyze_section(text, :writing),
      insights:    client.analyze_section(text, :insights)
    }
  end

  setup do
    results = self.class.eval_results
    skip "DEEPSEEK_API_KEY não configurada — evals requerem API real" unless results
    @results = results
  end

  # ── Ortografia ──────────────────────────────────────────────────────────────

  FINDINGS["orthography"].each do |exp|
    test "ortografia: encontra '#{exp["match"]}' — #{exp["description"]}" do
      assert_finding(:orthography, exp)
    end
  end

  # ── Insights Jurídicos ───────────────────────────────────────────────────────

  FINDINGS["legal_insights"].each do |exp|
    test "insight: detecta '#{exp["match"]}' — #{exp["description"]}" do
      assert_finding(:insights, exp)
    end
  end

  # ── Sugestões de Redação ─────────────────────────────────────────────────────

  FINDINGS["writing_suggestions"].each do |exp|
    test "redação: sugere melhoria para '#{exp["match"]}' — #{exp["description"]}" do
      assert_finding(:writing, exp)
    end
  end

  # ── Sanidade geral ───────────────────────────────────────────────────────────

  test "ortografia: retorna pelo menos 3 correções no contrato fixture" do
    count = @results[:orthography].length
    assert count >= 3, failure_summary(:orthography, ">= 3 correções", count)
  end

  test "insights: retorna pelo menos 2 riscos no contrato fixture" do
    count = @results[:insights].length
    assert count >= 2, failure_summary(:insights, ">= 2 riscos", count)
  end

  test "insights: nenhum item com risk_level inválido" do
    invalid = @results[:insights].reject { |i| %w[low medium high].include?(i["risk_level"]) }
    assert invalid.empty?,
      "risk_level inválido: #{invalid.map { |i| i["risk_level"] }.inspect}"
  end

  test "ortografia: nenhuma correção com original == suggestion" do
    identity = @results[:orthography].select { |i| i["original"] == i["suggestion"] }
    assert identity.empty?,
      "original == suggestion: #{identity.map { |i| i["original"] }.inspect}"
  end

  private

  def assert_finding(section, exp)
    items = @results[section]
    field = exp["field"]
    found = items.any? { |item| item.fetch(field, "").downcase.include?(exp["match"].downcase) }
    assert found, eval_failure_message(section, exp, items)
  end

  def eval_failure_message(section, exp, items)
    values = items.map { |i| i[exp["field"]] }.compact
    <<~MSG
      EVAL FALHOU: #{exp["description"]}
      Buscava '#{exp["match"]}' no campo '#{exp["field"]}' da seção :#{section}
      Valores encontrados (#{values.length} itens):
      #{values.map.with_index { |v, i| "  [#{i}] #{v.to_s[0, 100]}" }.join("\n").then { |s| s.empty? ? "  (nenhum)" : s }}
    MSG
  end

  def failure_summary(section, expectation, actual)
    items = @results[section]
    "Esperava #{expectation}, encontrou #{actual}.\n" \
    "Itens: #{items.map { |r| r.values.first }.inspect}"
  end
end
