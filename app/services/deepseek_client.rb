require "faraday"
require "json"

class DeepseekClient
  BASE_URL = "https://api.deepseek.com".freeze
  MAX_TEXT_LENGTH = 20_000
  MAX_FIELD_LENGTH = 600
  DISCLAIMER = "Análise informativa que não substitui consultoria jurídica profissional.".freeze

  VALID_RISK_LEVELS = %w[low medium high].freeze

  ENTITY_FIELDS = %w[
    contratante contratada objeto valor vigencia
    prazo_pagamento multa foro
  ].freeze

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

  def analyze_section(text, section)
    raise ProviderError, "DEEPSEEK_API_KEY não configurada." if @api_key.blank?

    truncated = text.to_s[0, MAX_TEXT_LENGTH]
    payload = build_section_payload(truncated, section)
    response = post(payload)
    content = extract_content(response)
    parse_section_json(content, section)
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

  def build_section_payload(text, section)
    {
      model: @model,
      messages: [
        { role: "system", content: "Responda somente em JSON válido." },
        { role: "user", content: build_section_prompt(text, section) }
      ],
      temperature: 0.1
    }
  end

  def build_section_prompt(text, section)
    header = <<~HEADER
      Você é um revisor jurídico especializado em direito brasileiro.
      REGRA FUNDAMENTAL: Só reporte itens com CERTEZA ABSOLUTA. Em caso de dúvida, não reporte.
      Prefira lista pequena e precisa a lista grande com itens duvidosos.
      O texto contém parágrafos indexados (ex: [Paragrafo 0] ...).

    HEADER

    body = case section
    when :orthography
      <<~BODY
        Analise APENAS erros ortográficos e gramaticais inequívocos.
        NÃO reporte: jargão jurídico, latinismos, termos técnicos, variações aceitas, palavras corretas em contexto jurídico.
        Reporte TODOS os erros encontrados, sem limite de quantidade.

        Retorne SOMENTE JSON válido:
        {"orthography":[{"original":"...","suggestion":"...","reason":"..."}]}
        Se não houver erros, retorne: {"orthography":[]}
      BODY
    when :writing
      <<~BODY
        Analise APENAS problemas de REDAÇÃO JURÍDICA: ambiguidade semântica, contradições
        lógicas entre cláusulas, imprecisão que gera insegurança jurídica, cláusulas incompletas.
        NÃO reporte: erros ortográficos, erros de digitação, erros de acentuação, erros
        de concordância gramatical — esses são tratados em seção separada.
        NÃO reporte: estilo pessoal, preferências subjetivas, trechos já corretos.
        Use 'excerpt' com o trecho EXATO do texto (copie literalmente).
        Reporte TODOS os problemas de redação encontrados, sem limite.

        Retorne SOMENTE JSON válido:
        {"writing_suggestions":[{"excerpt":"...","suggestion":"...","reason":"..."}]}
        Se não houver sugestões, retorne: {"writing_suggestions":[]}
      BODY
    when :insights
      <<~BODY
        Analise APENAS riscos jurídicos baseados em norma específica e identificável.
        NÃO reporte: especulações, riscos hipotéticos, interpretações forçadas.
        Classifique risco_level como: high (nulidade, inconstitucionalidade, violação de direito fundamental),
        medium (cláusula abusiva confirmada, ambiguidade que gera conflito real, falta de elemento essencial),
        low (imprecisão terminológica clara, redundância evidente).
        Reporte TODOS os riscos reais, sem limite de quantidade.
        Use paragraph_id com o número inteiro do parágrafo de origem.

        Retorne SOMENTE JSON válido:
        {"legal_insights":[{"topic":"...","insight":"...","risk_level":"low|medium|high","paragraph_id":INT}]}
        Se não houver riscos, retorne: {"legal_insights":[]}
      BODY
    when :entities
      <<~BODY
        Extraia as informações-chave deste contrato jurídico.
        REGRA ABSOLUTA: Copie EXATAMENTE o que está escrito no texto.
        Se uma informação não estiver explicitamente no texto, retorne null para esse campo.
        NUNCA invente, NUNCA infira, NUNCA complete com suposições.

        Retorne SOMENTE JSON válido com exatamente estas chaves:
        {
          "entities": {
            "contratante": "nome completo de quem contrata (cliente/comprador)",
            "contratada": "nome completo de quem presta o serviço",
            "objeto": "descrição objetiva do serviço ou produto (máx 150 chars)",
            "valor": "valor da remuneração com periodicidade (ex: R$ 5.000,00/mês)",
            "vigencia": "duração do contrato (ex: 12 meses a partir de 01/01/2026)",
            "prazo_pagamento": "quando o pagamento deve ser efetuado",
            "multa": "percentual ou valor da multa por descumprimento",
            "foro": "comarca ou cidade eleita para resolução de disputas"
          }
        }
        Use null (sem aspas) para campos não encontrados.
      BODY
    end

    "#{header}#{body}\nTexto:\n#{text}"
  end

  def parse_section_json(content, section)
    clean = strip_markdown(content.to_s.strip)
    parsed = begin
      JSON.parse(clean)
    rescue JSON::ParserError
      extracted = extract_json_object(clean)
      raise ResponseError, "DeepSeek retornou JSON inválido." if extracted.nil?
      JSON.parse(extracted)
    end

    case section
    when :entities
      normalize_entities(parsed["entities"])
    else
      key   = { orthography: "orthography", writing: "writing_suggestions", insights: "legal_insights" }[section]
      items = parsed[key] || []
      case section
      when :orthography then normalize_orthography(items)
      when :writing     then normalize_writing(items)
      when :insights    then normalize_insights(items)
      end
    end
  end

  def build_payload(text)
    {
      model: @model,
      messages: [
        { role: "system", content: "Responda somente em JSON válido." },
        { role: "user", content: build_prompt(text) }
      ],
      temperature: 0.1
    }
  end

  def build_prompt(text)
    <<~PROMPT
      Você é um revisor jurídico especializado em direito brasileiro. Sua função é identificar problemas REAIS e CONFIRMADOS — nunca inferir, nunca inventar.

      REGRA FUNDAMENTAL ANTI-ALUCINAÇÃO:
      - Só reporte um item se tiver CERTEZA ABSOLUTA. Em caso de dúvida, NÃO reporte.
      - Prefira uma lista pequena e precisa a uma lista grande com itens duvidosos.
      - Nunca corrija o que pode estar correto em determinado contexto jurídico.

      CONTEXTO JURÍDICO:
      - Aplique normas do português jurídico brasileiro (ABNT, terminologia forense).
      - Preserve jargão latino válido: in dubio pro reo, pacta sunt servanda, ad referendum, ex officio, habeas corpus, sub judice, entre outros.
      - Preserve termos técnicos jurídicos mesmo que incomuns.
      - Classifique risco jurídico apenas como:
          high: nulidade, inconstitucionalidade, violação de direito fundamental — somente quando explicitamente configurado no texto.
          medium: cláusula abusiva confirmada, ambiguidade que gera conflito real, falta de elemento essencial.
          low: imprecisão terminológica clara, redundância evidente.

      INSTRUÇÕES POR SEÇÃO:
      1. orthography: reporte APENAS erros ortográficos inequívocos (grafia errada, concordância errada, crase errada).
         NÃO reporte: palavras corretas em contexto jurídico, variações aceitas, termos técnicos, latinismos.
         Reporte TODOS os erros encontrados, sem limite de quantidade.

      2. writing_suggestions: reporte APENAS trechos onde a ambiguidade ou fraqueza de redação é objetiva e clara.
         NÃO reporte: estilo pessoal do redator, preferências subjetivas, trechos que já estão corretos.
         Use 'excerpt' com o trecho EXATO do texto (copie literalmente).

      3. legal_insights: reporte APENAS riscos baseados em norma jurídica específica e identificável.
         NÃO reporte: especulações, riscos hipotéticos, interpretações forçadas.
         Reporte TODOS os riscos reais encontrados, sem limite de quantidade.

      IMPORTANTE: O texto contém parágrafos indexados (ex: [Paragrafo 0] ...). Use o índice para paragraph_id.

      Retorne SOMENTE JSON válido, sem markdown, sem comentários, sem texto fora do JSON:
      {
        "orthography": [{"original":"...","suggestion":"...","reason":"..."}],
        "writing_suggestions": [{"excerpt":"...","suggestion":"...","reason":"..."}],
        "legal_insights": [{"topic":"...","insight":"...","risk_level":"low|medium|high","paragraph_id":INT}]
      }
      Se não houver itens em alguma seção, retorne lista vazia.

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
      "orthography" => normalize_orthography(payload["orthography"]),
      "writing_suggestions" => normalize_writing(payload["writing_suggestions"]),
      "legal_insights" => normalize_insights(payload["legal_insights"])
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

  def normalize_entities(raw)
    return ENTITY_FIELDS.index_with(nil) unless raw.is_a?(Hash)
    ENTITY_FIELDS.each_with_object({}) do |field, result|
      value = raw[field].to_s.strip
      result[field] = value.present? ? value[0, 200] : nil
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
