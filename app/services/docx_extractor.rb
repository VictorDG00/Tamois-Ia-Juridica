require "zip"
require "nokogiri"

class DocxExtractor
  WORD_DOCUMENT_PATH = "word/document.xml".freeze
  NS = { "w" => "http://schemas.openxmlformats.org/wordprocessingml/2006/main" }.freeze

  def self.extract(file_path)
    new(file_path).extract
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def extract
    xml = read_document_xml
    doc = Nokogiri::XML(xml)

    paragraphs = doc.xpath("//w:p", NS).map.with_index do |para, idx|
      text = para.xpath(".//w:t", NS).map(&:text).join(" ").strip
      text.empty? ? nil : "[Paragrafo #{idx}] #{text}"
    end.compact

    paragraphs.join("\n")
  end

  private

  def read_document_xml
    Zip::File.open(@file_path) do |zip|
      entry = zip.find_entry(WORD_DOCUMENT_PATH)
      raise ArgumentError, "Arquivo DOCX inválido: word/document.xml não encontrado" unless entry
      entry.get_input_stream.read
    end
  end
end
