class Analysis < ApplicationRecord
  belongs_to :user
  has_many :chat_messages, dependent: :destroy
  has_one_attached :docx_file

  STATUSES = %w[pending processing completed failed].freeze

  validates :filename, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :analysis_mode, inclusion: { in: %w[fast deep] }

  before_validation :set_defaults

  def orthography
    JSON.parse(orthography_json || "[]")
  rescue JSON::ParserError
    []
  end

  def writing_suggestions
    JSON.parse(writing_suggestions_json || "[]")
  rescue JSON::ParserError
    []
  end

  def legal_insights
    JSON.parse(legal_insights_json || "[]")
  rescue JSON::ParserError
    []
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def processing?
    status == "processing"
  end

  def pending?
    status == "pending"
  end

  private

  def set_defaults
    self.status ||= "pending"
    self.analysis_mode ||= "fast"
  end
end
