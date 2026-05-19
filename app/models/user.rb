class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :analyses, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }

  def analyses_used
    analyses.count
  end
end
