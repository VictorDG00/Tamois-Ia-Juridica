class ChatMessage < ApplicationRecord
  belongs_to :analysis

  ROLES = %w[user assistant].freeze

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true
end
