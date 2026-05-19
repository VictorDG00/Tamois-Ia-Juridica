class AnalysisFeedback < ApplicationRecord
  belongs_to :analysis
  belongs_to :user

  SECTIONS = %w[orthography writing insights entities].freeze
  VERDICTS = %w[incorrect].freeze

  validates :section, inclusion: { in: SECTIONS }
  validates :item_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :verdict, inclusion: { in: VERDICTS }

  def item_data
    JSON.parse(item_snapshot || "{}")
  rescue JSON::ParserError
    {}
  end

  def section_label
    { "orthography" => "Ortografia", "writing" => "Redação",
      "insights" => "Insights jurídicos", "entities" => "Entidades" }[section] || section
  end
end
