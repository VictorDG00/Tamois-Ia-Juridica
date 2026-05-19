require "test_helper"
require "zip"
require "nokogiri"

class DocxAnnotatorTest < ActiveSupport::TestCase
  W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main".freeze
  NS   = { "w" => W_NS }.freeze

  def setup
    @user     = create_user
    @analysis = create_analysis(user: @user, status: "completed")
    @analysis.update!(
      orthography_json: [
        { "original" => "rescição", "suggestion" => "rescisão", "reason" => "Grafia correta" }
      ].to_json,
      writing_suggestions_json: [
        { "excerpt" => "O prazo será determinado", "suggestion" => "O prazo será de 30 dias corridos", "reason" => "Precisão temporal" }
      ].to_json,
      legal_insights_json: [
        { "topic" => "Cláusula de rescisão", "insight" => "Risco de nulidade por falta de prazo.", "risk_level" => "high", "paragraph_id" => 1 }
      ].to_json
    )
    attach_test_docx(@analysis)
  end

  test "gera um ZIP válido" do
    bytes = DocxAnnotator.new(@analysis).generate
    assert bytes.present?
    assert_nothing_raised { open_zip(bytes) }
  end

  test "ZIP contém word/document.xml" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      assert zip.find_entry("word/document.xml"), "document.xml não encontrado"
    end
  end

  test "ZIP contém word/comments.xml" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      assert zip.find_entry("word/comments.xml"), "comments.xml não encontrado"
    end
  end

  test "Track Change inserido para correção ortográfica" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      doc = parse_xml(zip, "word/document.xml")
      assert doc.at_xpath("//w:del", NS), "Esperava <w:del> no document.xml"
      assert doc.at_xpath("//w:ins", NS), "Esperava <w:ins> no document.xml"
      assert_includes doc.at_xpath("//w:del//w:delText", NS).text, "rescição"
      assert_includes doc.at_xpath("//w:ins//w:t", NS).text, "rescisão"
    end
  end

  test "Track Change preserva o author Tamois" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      doc = parse_xml(zip, "word/document.xml")
      assert_equal "Tamois", doc.at_xpath("//w:del", NS)["w:author"]
    end
  end

  test "Commentários ancorados no document.xml" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      doc = parse_xml(zip, "word/document.xml")
      assert doc.at_xpath("//w:commentRangeStart", NS)
      assert doc.at_xpath("//w:commentRangeEnd", NS)
      assert doc.at_xpath("//w:commentReference", NS)
    end
  end

  test "comments.xml contém insight jurídico" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      xml = read_entry(zip, "word/comments.xml")
      assert_includes xml, "Cláusula de rescisão"
      assert_includes xml, "🔴"
      assert_includes xml, "RISCO HIGH"
    end
  end

  test "comments.xml contém sugestão de redação" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      xml = read_entry(zip, "word/comments.xml")
      assert_includes xml, "SUGESTÃO DE REDAÇÃO"
      assert_includes xml, "prazo será de 30 dias"
    end
  end

  test ".rels inclui referência ao comments.xml" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      xml = read_entry(zip, "word/_rels/document.xml.rels")
      assert_includes xml, "comments.xml"
    end
  end

  test "[Content_Types].xml inclui tipo do comments" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      xml = read_entry(zip, "[Content_Types].xml")
      assert_includes xml, "comments"
    end
  end

  test "não levanta exceção quando não há correções" do
    analysis = create_analysis(user: @user, status: "completed")
    analysis.update!(
      orthography_json: [].to_json,
      writing_suggestions_json: [].to_json,
      legal_insights_json: [].to_json
    )
    attach_test_docx(analysis)
    assert_nothing_raised { DocxAnnotator.new(analysis).generate }
  end

  test "IDs de Track Change são únicos entre del e ins" do
    open_zip(DocxAnnotator.new(@analysis).generate) do |zip|
      doc    = parse_xml(zip, "word/document.xml")
      del_id = doc.at_xpath("//w:del", NS)["w:id"]
      ins_id = doc.at_xpath("//w:ins", NS)["w:id"]
      refute_equal del_id, ins_id, "del e ins não devem compartilhar o mesmo w:id"
    end
  end

  private

  def open_zip(bytes, &block)
    Zip::File.open_buffer(StringIO.new(bytes), &block)
  end

  def parse_xml(zip, entry_name)
    Nokogiri::XML(read_entry(zip, entry_name))
  end

  def read_entry(zip, name)
    zip.find_entry(name).get_input_stream.read.force_encoding("UTF-8")
  end

  def attach_test_docx(analysis)
    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="#{DocxAnnotator::W_NS}">
        <w:body>
          <w:p><w:r><w:t>CONTRATO DE PRESTAÇÃO DE SERVIÇOS</w:t></w:r></w:p>
          <w:p><w:r><w:t xml:space="preserve">A rescição do contrato e o prazo serão determinados pelas partes. O prazo será determinado conforme acordo.</w:t></w:r></w:p>
          <w:p><w:r><w:t>Cláusula de rescisão: nos termos do artigo 473 do Código Civil.</w:t></w:r></w:p>
        </w:body>
      </w:document>
    XML

    docx = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("word/document.xml")
      zip.write(xml)
      zip.put_next_entry("word/_rels/document.xml.rels")
      zip.write(<<~RELS)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
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

    analysis.docx_file.attach(
      io:           StringIO.new(docx),
      filename:     "test.docx",
      content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )
  end
end
