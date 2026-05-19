require "faraday"
require "json"

class DeepseekClient
  BASE_URL = "https://api.deepseek.com".freeze
  MAX_TEXT_LENGTH = 20_000
  MAX_ITEMS_PER_SECTION = 8
  MAX_FIELD_LENGTH = 400
  DISCLAIMER = "Análise informativa que não substitui consultoria jurídica profissional.".freeze

  VALID_RISK_LEVELS = %w[low medium high].freeze

  class ProviderError < StandardError; end
  class TimeoutError < ProviderError; end
  class ResponseError < ProviderError; end

  def initialize(api_key: nil, model: "deepseek-chat", timeout: 90)
    @api_key = api_key || ENV.fetch("DEEPSEEK_API_KEY", "")
    @model = model
    @timeout = timeout
  end

  def analyze(text)
    raise ProviderError, "DEEPSEEK_API_KEY não configurada." if @api_key.blank?

    truncated = text.to_s[0, MAX_TEXT_LENGTH]
    payload = build_payload(truncated)

    response = post(payload)
    content = extract_content(response)
    parsed = parse_json(content)
    normalize(parsed)
  end

  def chat(messages)
    raise ProviderError, "DEEPSEEK_API_KEY não configurada." if @api_key.blank?

    payload = {
      model: @model,
      messages: messages,
      temperature: 0.5
    }

    response = post(payload)
    extract_content(response)
  end

  private

  def build_payload(text)
    {
      model: @model,
      messages: [
        { role: "system", content: "Responda somente em JSON válido." },
        { role: "user", content: build_prompt(text) }
      ],
      temperature: 0.2
    }
  end

  def build_prompt(text)
    <<~PROMPT
      Você é um revisor jurídico especializado em direito brasileiro.

      CONTEXTO JURÍDICO:
      - Aplique normas do português jurídico brasileiro (ABNT, terminologia forense).
      - Reconheça e preserve jargão latino válido: in dubio pro reo, pacta sunt servanda, ad referendum, ex officio, habeas corpus, sub judice, entre outros.
      - Conheça categorias de cláusula: rescisão, vigência, penalidade, confidencialidade, responsabilidade civil, foro, objeto, preço, garantia, cessão de direitos.
      - Classifique risco jurídico como:
          high: nulidade, inconstitucionalidade, crime, dano irreparável, violação de direito fundamental.
          medium: cláusula abusiva, ambiguidade crítica, prazo irregular, falta de elemento essencial.
          low: imprecisão terminológica, redundância, sugestão de clareza.

      INSTRUÇÕES:
      1. orthography: corrija apenas erros ortográficos e gramaticais reais. Não altere jargão jurídico correto.
      2. writing_suggestions: proponha reescrita de trechos ambíguos, redundantes ou de redação jurídica fraca.
         Use 'excerpt' com o trecho exato do texto e 'suggestion' com a versão melhorada.
      3. legal_insights: identifique riscos jurídicos por cláusula. Use 'topic' como nome da cláusula ou tema,
         'insight' com a análise objetiva, 'risk_level' conforme classificação acima,
         e 'paragraph_id' com o número inteiro do parágrafo de origem.

      IMPORTANTE: O texto contém parágrafos indexados (ex: [Paragrafo 0] ...). Use o índice para paragraph_id.

      Retorne SOMENTE JSON válido, sem markdown, sem comentários, sem texto fora do JSON:
      {
        "orthography": [{"original":"...","suggestion":"...","reason":"..."}],
        "writing_suggestions": [{"excerpt":"...","suggestion":"...","reason":"..."}],
        "legal_insights": [{"topic":"...","insight":"...","risk_level":"low|medium|high","paragraph_id":INT}]
      }
      Se não houver itens em alguma seção, retorne lista vazia. Seja objetivo e conciso.

      Texto:
      #{text}
    PROMPT
  end

  def post(payload)
    conn = Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    response = conn.post("/chat/completions") do |req|
      req.headers["Authorization"] = "Bearer #{@api_key}"
      req.headers["Content-Type"] = "application/json"
      req.body = payload
      req.options.timeout = @timeout
    end

    raise ProviderError, "DeepSeek retornou HTTP #{response.status}" if response.status >= 400

    response.body
  rescue Faraday::TimeoutError
    raise TimeoutError, "Timeout ao consultar DeepSeek."
  rescue Faraday::Error => e
    raise ProviderError, "Falha de comunicação com DeepSeek: #{e.message}"
  end

  def extract_content(body)
    body.dig("choices", 0, "message", "content") ||
      raise(ResponseError, "Resposta malformada do DeepSeek.")
  end

  def parse_json(content)
    clean = strip_markdown(content.to_s.strip)
    JSON.parse(clean)
  rescue JSON::ParserError
    extracted = extract_json_object(clean)
    raise ResponseError, "DeepSeek retornou JSON inválido." if extracted.nil?
    JSON.parse(extracted)
  rescue JSON::ParserError
    raise ResponseError, "DeepSeek retornou JSON inválido."
  end

  def normalize(payload)
    {
      "orthography" => normalize_orthography(payload["orthography"]).first(MAX_ITEMS_PER_SECTION),
      "writing_suggestions" => normalize_writing(payload["writing_suggestions"]).first(MAX_ITEMS_PER_SECTION),
      "legal_insights" => normalize_insights(payload["legal_insights"]).first(MAX_ITEMS_PER_SECTION)
    }
  end

  def normalize_orthography(items)
    return [] unless items.is_a?(Array)
    items.filter_map do |item|
      next unless item.is_a?(Hash)
      original = safe_text(item["original"])
      suggestion = safe_text(item["suggestion"])
      next if original.blank? || suggestion.blank?
      { "original" => original, "suggestion" => suggestion, "reason" => safe_text(item["reason"]) }
    end
  end

  def normalize_writing(items)
    return [] unless items.is_a?(Array)
    items.filter_map do |item|
      next unless item.is_a?(Hash)
      excerpt = safe_text(item["excerpt"])
      suggestion = safe_text(item["suggestion"])
      next if excerpt.blank? || suggestion.blank?
      { "excerpt" => excerpt, "suggestion" => suggestion, "reason" => safe_text(item["reason"]) }
    end
  end

  def normalize_insights(items)
    return [] unless items.is_a?(Array)
    items.filter_map do |item|
      next unless item.is_a?(Hash)
      topic = safe_text(item["topic"])
      insight_content = safe_text(item["insight"])
      next if topic.blank? || insight_content.blank?

      risk_level = item["risk_level"].to_s.downcase
      risk_level = "medium" unless VALID_RISK_LEVELS.include?(risk_level)

      paragraph_id = parse_paragraph_id(item["paragraph_id"])

      insight_limit = MAX_FIELD_LENGTH - DISCLAIMER.length - 1
      insight_content = insight_content[0, insight_limit] if insight_content.length > insight_limit
      insight_text = "#{insight_content} #{DISCLAIMER}".strip

      {
        "topic" => topic,
        "insight" => insight_text,
        "risk_level" => risk_level,
        "paragraph_id" => paragraph_id
      }
    end
  end

  def safe_text(value)
    text = value.to_s.strip
    text[0, MAX_FIELD_LENGTH]
  end

  def parse_paragraph_id(value)
    return -1 if value.nil?
    result = Integer(Float(value.to_s))
    result >= 0 ? result : -1
  rescue ArgumentError, TypeError
    -1
  end

  def strip_markdown(text)
    match = text.match(/\A```(?:json)?\s*(.*?)\s*```\z/m)
    match ? match[1].strip : text
  end

  def extract_json_object(text)
    start = text.index("{")
    finish = text.rindex("}")
    return nil if start.nil? || finish.nil? || finish <= start
    text[start..finish]
  end
end
