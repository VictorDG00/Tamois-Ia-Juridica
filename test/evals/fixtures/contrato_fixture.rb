require "zip"

# Gera o DOCX do contrato fixture em memória.
# O contrato tem erros INTENCIONAIS mapeados em test/evals/expected_findings.yml.
# Não altere este arquivo sem atualizar o YAML correspondente.
module ContratoFixture
  TEXTO = <<~CONTRATO
    CONTRATO DE PRESTAÇÃO DE SERVIÇOS DE CONSULTORIA

    CONTRATANTE: Empresa Alpha Ltda., inscrita no CNPJ sob o nº 12.345.678/0001-99,
    com sede na Rua das Flores, 100, São Paulo - SP, CEP 01310-100,
    neste ato representada por seu sócio-administrador João da Silva.

    CONTRATADA: Consultoria Beta S.A., inscrita no CNPJ sob o nº 98.765.432/0001-11,
    com sede na Avenida Paulista, 1000, São Paulo - SP, CEP 01310-200,
    representada por Maria Oliveira, Diretora Executiva.

    As partes acima qualificadas resolvem celebrar o presente Contrato de
    Prestação de Serviços, que se regerá pelas cláusulas e condições seguintes:

    CLÁUSULA 1ª - OBJETO
    O presente instrumento tem por objeto a prestação de serviços de consultoria
    estratégica e juridica pela CONTRATADA à CONTRATANTE, abrangendo análise
    de contratos, pareceres e acompanhamento de processos administrativos.

    CLÁUSULA 2ª - VIGÊNCIA
    O presente contrato vigorará pelo prazo de 12 (doze) meses, com inicio em
    01 de Janeiro de 2026, podendo ser prorrogado por igual período mediante
    acordo escrito entre as partes. O contrato entrará em vigor na data de
    sua assinatura pelas partes.

    CLÁUSULA 3ª - REMUNERAÇÃO
    Pelos serviços prestados, a CONTRATANTE pagará à CONTRATADA o valor mensal
    de R$ 15.000,00 (quinze mil reais), devendo o pagamento ser efetuado até
    o 5º dia util de cada mês subsequente ao da prestação dos serviços,
    mediante emissão de nota fiscal.

    CLÁUSULA 4ª - RESCISÃO E PENALIDADES
    Em caso de descumprimento de qualquer das obrigações previstas neste
    instrumento, a parte inadimplente estará sujeita ao pagamento de multa
    equivalente a 30% (trinta por cento) sobre o valor total do contrato,
    sem prejuízo de perdas e danos. A rescição poderá ocorrer de forma
    unilateral e imediata, sem necessidade de notificação prévia, a critério
    exclusivo da parte que se sentir prejudicada.

    CLÁUSULA 5ª - CONFIDENCIALIDADE
    As partes se comprometem a manter sigilo absoluto sobre todas as informações
    confidenciais trocadas durante a execução deste contrato e após o seu
    encerramento, por prazo indeterminado, sob pena de rescisão imediata e
    pagamento de indenização.

    CLÁUSULA 6ª - PROPRIEDADE INTELECTUAL
    Todos os trabalhos, relatórios, pareceres e demais produtos intelectuais
    desenvolvidos pela CONTRATADA no âmbito deste contrato serão de
    propriedade exclusiva da CONTRATANTE, independente de qualquer
    remuneração adicional, sem direito a qualquer compensação futura
    pela cessão dos direitos autorais patrimoniais.

    CLÁUSULA 7ª - DISPOSIÇÕES GERAIS
    O presente instrumento, juntamente com seus anexos, constitui o acordo
    integral entre as partes. As duvidas surgidas na execução deste contrato
    serão resolvidas de comum acordo. Fica eleito o foro da Comarca de
    São Paulo para dirimir quaisquer controvérsias decorrentes do presente
    instrumento, renunciando as partes a qualquer outro, por mais privilegiado
    que seja.

    São Paulo, 01 de Janeiro de 2026.

    _______________________________        _______________________________
    CONTRATANTE                            CONTRATADA
    Empresa Alpha Ltda.                    Consultoria Beta S.A.
    João da Silva                          Maria Oliveira
  CONTRATO

  def self.generate_docx
    paragraphs = TEXTO.split("\n").map(&:strip).reject(&:empty?)

    document_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          #{paragraphs.map.with_index { |p, i|
            "<w:p><w:r><w:t xml:space=\"preserve\">#{p.gsub('&','&amp;').gsub('<','&lt;').gsub('>','&gt;')}</w:t></w:r></w:p>"
          }.join("\n          ")}
        </w:body>
      </w:document>
    XML

    Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("word/document.xml")
      zip.write(document_xml)
      zip.put_next_entry("word/_rels/document.xml.rels")
      zip.write(<<~RELS)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
      RELS
      zip.put_next_entry("[Content_Types].xml")
      zip.write(<<~CT)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
      CT
    end.string
  end

  def self.plain_text
    DocxExtractor.extract_from_string(generate_docx)
  end
end
