class User < ApplicationRecord
  has_many :projects, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  # Index and show windows both listen on the collection stream, so any change
  # refreshes every window that lists or shows users.
  broadcasts_refreshes_to ->(user) { user.model_name.plural }

  def to_s = name
end
