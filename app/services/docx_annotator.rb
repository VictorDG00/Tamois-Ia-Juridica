require "zip"
require "nokogiri"

class DocxAnnotator
  W_NS   = "http://schemas.openxmlformats.org/wordprocessingml/2006/main".freeze
  NS     = { "w" => W_NS }.freeze
  AUTHOR = "Tamois".freeze
  RISK_EMOJI = { "high" => "🔴", "medium" => "🟡", "low" => "🟢" }.freeze

  def initialize(analysis)
    @analysis        = analysis
    @next_id         = 0
    @comment_entries = []
  end

  def generate
    path    = ActiveStorage::Blob.service.path_for(@analysis.docx_file.key)
    entries = read_zip(path)

    doc        = Nokogiri::XML(entries["word/document.xml"])
    paragraphs = doc.xpath("//w:p", NS).to_a

    apply_orthography(paragraphs)
    apply_writing_comments(paragraphs)
    apply_insight_comments(paragraphs)

    entries["word/document.xml"]            = doc.to_xml(encoding: "UTF-8")
    entries["word/comments.xml"]            = build_comments_xml
    entries["word/_rels/document.xml.rels"] = patch_rels(entries["word/_rels/document.xml.rels"])
    entries["[Content_Types].xml"]          = patch_content_types(entries["[Content_Types].xml"])

    write_zip(entries)
  end

  private

  # ── Helpers ────────────────────────────────────────────────────────────────

  def next_id
    @next_id += 1
  end

  def date_str
    @date_str ||= Time.current.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  # Escapes special XML characters in text content
  def xe(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
  end

  # ── ZIP I/O ────────────────────────────────────────────────────────────────

  def read_zip(path)
    entries = {}
    Zip::File.open(path) do |zip|
      zip.each { |e| entries[e.name] = e.get_input_stream.read unless e.directory? }
    end
    entries
  end

  def write_zip(entries)
    Zip::OutputStream.write_buffer do |zip|
      entries.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end.string
  end

  # ── ORTHOGRAPHY → Track Changes ────────────────────────────────────────────

  def apply_orthography(paragraphs)
    @analysis.orthography.each do |item|
      original   = item["original"].to_s.strip
      suggestion = item["suggestion"].to_s.strip
      next if original.blank? || suggestion.blank? || original == suggestion

      paragraphs.each { |p| break if apply_track_change(p, original, suggestion) }
    end
  end

  def apply_track_change(para, original, suggestion)
    runs = para.xpath("w:r[w:t]", NS).to_a
    return false if runs.empty?

    offset  = 0
    run_map = runs.map do |run|
      text   = run.at_xpath("w:t", NS).text
      entry  = { run: run, text: text, start: offset, finish: offset + text.length }
      offset += text.length
      entry
    end

    full_text = run_map.map { |r| r[:text] }.join
    pos       = full_text.index(original)
    return false unless pos

    pos_end  = pos + original.length
    affected = run_map.select { |r| r[:finish] > pos && r[:start] < pos_end }
    return false if affected.empty?

    first_r  = affected.first
    last_r   = affected.last
    rpr_xml  = first_r[:run].at_xpath("w:rPr", NS)&.to_xml.to_s
    before_t = first_r[:text][0, pos - first_r[:start]]
    after_t  = last_r[:text][(pos_end - last_r[:start])..]
    anchor   = first_r[:run]

    anchor.before(run_xml_node(before_t, rpr_xml))          if before_t.present?
    anchor.before(del_xml_node(original, rpr_xml, next_id))
    anchor.before(ins_xml_node(suggestion, rpr_xml, next_id))
    anchor.before(run_xml_node(after_t, rpr_xml))           if after_t.present?

    affected.each { |r| r[:run].remove }
    true
  end

  def run_xml_node(text, rpr_xml)
    Nokogiri::XML(
      %Q(<w:r xmlns:w="#{W_NS}">#{rpr_xml}<w:t xml:space="preserve">#{xe(text)}</w:t></w:r>)
    ).root
  end

  def del_xml_node(text, rpr_xml, id)
    Nokogiri::XML(
      %Q(<w:del xmlns:w="#{W_NS}" w:id="#{id}" w:author="#{xe(AUTHOR)}" w:date="#{date_str}"><w:r>#{rpr_xml}<w:delText xml:space="preserve">#{xe(text)}</w:delText></w:r></w:del>)
    ).root
  end

  def ins_xml_node(text, rpr_xml, id)
    Nokogiri::XML(
      %Q(<w:ins xmlns:w="#{W_NS}" w:id="#{id}" w:author="#{xe(AUTHOR)}" w:date="#{date_str}"><w:r>#{rpr_xml}<w:t xml:space="preserve">#{xe(text)}</w:t></w:r></w:ins>)
    ).root
  end

  # ── WRITING SUGGESTIONS → Comments ────────────────────────────────────────

  def apply_writing_comments(paragraphs)
    @analysis.writing_suggestions.each do |item|
      excerpt    = item["excerpt"].to_s.strip
      suggestion = item["suggestion"].to_s.strip
      reason     = item["reason"].to_s.strip
      next if excerpt.blank? || suggestion.blank?

      target = paragraphs.find do |p|
        p.xpath(".//w:t", NS).map(&:text).join.include?(excerpt[0, 40])
      end
      next unless target

      lines = ["💬 SUGESTÃO DE REDAÇÃO", "",
               "Trecho: \"#{excerpt[0, 120]}\"", "",
               "Sugestão: #{suggestion}"]
      lines += ["", "Motivo: #{reason}"] if reason.present?
      add_comment_to_paragraph(target, lines.join("\n"))
    end
  end

  # ── LEGAL INSIGHTS → Comments ─────────────────────────────────────────────

  def apply_insight_comments(paragraphs)
    @analysis.legal_insights.each do |item|
      pid    = item["paragraph_id"].to_i
      target = (pid >= 0 ? paragraphs[pid] : nil)
      target ||= paragraphs.find do |p|
        t = item["topic"].to_s
        t.length > 8 && p.xpath(".//w:t", NS).map(&:text).join.include?(t[0, 20])
      end
      next unless target

      emoji = RISK_EMOJI[item["risk_level"]] || "⚪"
      level = item["risk_level"].to_s.upcase
      lines = ["#{emoji} RISCO #{level} — #{item["topic"]}", "", item["insight"]]
      add_comment_to_paragraph(target, lines.join("\n"))
    end
  end

  # ── Comment anchoring ─────────────────────────────────────────────────────

  def add_comment_to_paragraph(para, text)
    cid = next_id
    @comment_entries << { id: cid, text: text }
    decl = %Q(xmlns:w="#{W_NS}")

    cs     = Nokogiri::XML(%Q(<w:commentRangeStart #{decl} w:id="#{cid}"/>)).root
    ce     = Nokogiri::XML(%Q(<w:commentRangeEnd #{decl} w:id="#{cid}"/>)).root
    cr_run = Nokogiri::XML(
      %Q(<w:r #{decl}><w:rPr><w:rStyle w:val="CommentReference"/></w:rPr><w:commentReference w:id="#{cid}"/></w:r>)
    ).root

    first = para.children.first
    first ? first.before(cs) : para.add_child(cs)
    para.add_child(ce)
    para.add_child(cr_run)
  end

  # ── Build word/comments.xml ────────────────────────────────────────────────

  def build_comments_xml
    lines = [
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
      %Q(<w:comments xmlns:w="#{W_NS}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">)
    ]

    @comment_entries.each do |entry|
      lines << %Q(  <w:comment w:id="#{entry[:id]}" w:author="#{xe(AUTHOR)}" w:date="#{date_str}" w:initials="T">)
      entry[:text].split("\n").each_with_index do |line, i|
        lines << "    <w:p>"
        if i == 0
          lines << '      <w:pPr><w:pStyle w:val="CommentText"/></w:pPr>'
          lines << '      <w:r><w:rPr><w:rStyle w:val="CommentReference"/></w:rPr><w:annotationRef/></w:r>'
        end
        lines << %Q(      <w:r><w:t xml:space="preserve">#{xe(line)}</w:t></w:r>)
        lines << "    </w:p>"
      end
      lines << "  </w:comment>"
    end

    lines << "</w:comments>"
    lines.join("\n")
  end

  # ── Patch word/_rels/document.xml.rels ────────────────────────────────────

  def patch_rels(rels_xml)
    return default_rels if rels_xml.blank?
    return rels_xml if rels_xml.include?("comments")

    doc    = Nokogiri::XML(rels_xml)
    max_id = doc.xpath("//@Id").map { |a| a.value.scan(/\d+/).first.to_i }.max || 0
    type   = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments"

    rel = doc.create_element("Relationship",
      "Id" => "rId#{max_id + 1}", "Type" => type, "Target" => "comments.xml")
    doc.root.add_child(rel)
    doc.to_xml(encoding: "UTF-8")
  end

  def default_rels
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="comments.xml"/>
      </Relationships>
    XML
  end

  # ── Patch [Content_Types].xml ──────────────────────────────────────────────

  def patch_content_types(ct_xml)
    return default_content_types if ct_xml.blank?
    return ct_xml if ct_xml.include?("comments")

    doc = Nokogiri::XML(ct_xml)
    doc.root.add_child(doc.create_element("Override",
      "PartName"    => "/word/comments.xml",
      "ContentType" => "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"))
    doc.to_xml(encoding: "UTF-8")
  end

  def default_content_types
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Override PartName="/word/comments.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"/>
      </Types>
    XML
  end
end
