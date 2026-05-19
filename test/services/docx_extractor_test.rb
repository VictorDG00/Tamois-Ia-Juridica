require "test_helper"
require "zip"
require "tmpdir"

class DocxExtractorTest < ActiveSupport::TestCase
  def create_test_docx(paragraphs)
    dir = Dir.mktmpdir
    path = File.join(dir, "test.docx")

    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
                  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          #{paragraphs.map { |p| "<w:p><w:r><w:t>#{p}</w:t></w:r></w:p>" }.join}
        </w:body>
      </w:document>
    XML

    Zip::OutputStream.open(path) do |zip|
      zip.put_next_entry("word/document.xml")
      zip.write(xml)
    end

    path
  end

  test "extracts text from valid docx" do
    path = create_test_docx(["Cláusula primeira.", "O contrato vigora por 12 meses."])
    text = DocxExtractor.extract(path)
    assert_includes text, "Cláusula primeira."
    assert_includes text, "O contrato vigora por 12 meses."
  end

  test "indexes paragraphs with [Paragrafo N] prefix" do
    path = create_test_docx(["Paragrafo zero", "Paragrafo um"])
    text = DocxExtractor.extract(path)
    assert_match(/\[Paragrafo \d+\]/, text)
  end

  test "ignores empty paragraphs" do
    path = create_test_docx(["", "Texto real", "   "])
    text = DocxExtractor.extract(path)
    refute_match(/\[Paragrafo.*\]\s*$/, text)
    assert_includes text, "Texto real"
  end

  test "raises error for invalid docx" do
    path = Tempfile.new(["bad", ".docx"]).path
    File.write(path, "not a zip")
    assert_raises { DocxExtractor.extract(path) }
  end

  test "raises error when word/document.xml missing" do
    dir = Dir.mktmpdir
    path = File.join(dir, "empty.docx")
    Zip::OutputStream.open(path) do |zip|
      zip.put_next_entry("other/file.xml")
      zip.write("<root/>")
    end
    assert_raises(ArgumentError) { DocxExtractor.extract(path) }
  end
end
