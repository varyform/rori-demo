class Project < ApplicationRecord
  STATUSES = %w[ idea active paused done ].freeze

  belongs_to :user, touch: true

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  broadcasts_refreshes_to ->(project) { project.model_name.plural }

  def self.human_status(status) = I18n.t(status, scope: "activerecord.values.project.status")

  def human_status = self.class.human_status(status)

  def to_s = name
end
