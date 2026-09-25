class Service < ApplicationRecord
  REGIONS = %w[ fra1 ams3 lon1 nyc1 sfo3 ].freeze
  SIZES = %w[ small medium large ].freeze

  belongs_to :user

  validates :name, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, allow_blank: true }
  validates :repository, format: { with: %r{\Ahttps?://\S+\z}, allow_blank: true }
  validates :branch, :health_check_path, presence: true
  validates :region, inclusion: { in: REGIONS }
  validates :size, inclusion: { in: SIZES }
  validates :replicas, numericality: { only_integer: true, in: 1..20 }
  validate :environment_lines_are_assignments

  broadcasts_refreshes_to ->(service) { service.model_name.plural }

  def self.human_size(size) = I18n.t(size, scope: "activerecord.values.service.size")

  def human_size = self.class.human_size(size)

  def environment_keys = environment.to_s.lines.filter_map { it[/\A\s*([A-Z0-9_]+)=/, 1] }

  def to_s = name

  private
    def environment_lines_are_assignments
      invalid = environment.to_s.lines.map(&:strip).reject { it.blank? || it.match?(/\A[A-Z0-9_]+=/) }
      errors.add(:environment, :assignments, lines: invalid.first(3).join(", ")) if invalid.any?
    end
end
