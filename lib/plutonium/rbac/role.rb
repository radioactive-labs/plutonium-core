# frozen_string_literal: true

module Plutonium
  module Rbac
    class Role < ActiveRecord::Base
      include Plutonium::Resource::Record

      self.table_name = "plutonium_rbac_roles"

      # Pinned for clean routes/helpers (rbac_roles_path), as AsyncRun does.
      MODEL_NAME = ActiveModel::Name.new(self, nil, "RbacRole")

      def self.model_name = MODEL_NAME

      belongs_to :entity, polymorphic: true, optional: true
      # foreign_key: the pinned model name would infer rbac_role_id.
      has_many :assignments, class_name: "Plutonium::Rbac::RoleAssignment", foreign_key: :role_id, inverse_of: :role,
        dependent: :restrict_with_error

      scope :global, -> { where(entity_type: nil, entity_id: nil) }

      before_validation { self.key = name.to_s.parameterize(separator: "_") if key.blank? }

      validates :name, presence: true
      validates :key, presence: true, uniqueness: {scope: %i[entity_type entity_id]}
      validate :permissions_exist
      validate :permissions_grantable

      after_commit { Current.invalidate! }

      def permissions=(value)
        super(Array(value).compact_blank.map(&:to_s).uniq.sort)
      end

      def to_label = name

      private

      def permissions_exist
        permissions.each do |key|
          if key == "*" || key.end_with?(".*")
            errors.add(:permissions, :rbac_wildcard_not_allowed, key:) unless system_role?
          elsif !Catalog.key?(key)
            errors.add(:permissions, :rbac_unknown_permission, key:)
          end
        end
      end

      def permissions_grantable
        added = permissions - (new_record? ? [] : Array(permissions_was))
        denied = Rbac.ungrantable_keys(added)
        errors.add(:permissions, :rbac_not_grantable, keys: denied.join(", ")) if denied.any?
      end
    end
  end
end
