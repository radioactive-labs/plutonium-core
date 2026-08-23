# frozen_string_literal: true

require "yaml"

module Plutonium
  module Doctor
    # `.plutonium-doctor.yml`, read from the application root.
    #
    # Suppression exists from the first release on purpose. Every check here is
    # a judgement about intent, and some of those judgements will be wrong about
    # a particular line — a condition that reads like a role check but is not, a
    # redundant-looking declaration kept deliberately. A checker with no way to
    # say "yes, I meant that" gets muted wholesale, and then it may as well not
    # run at all.
    #
    #   # .plutonium-doctor.yml
    #   disable:
    #     - redundant_field_declaration
    #   ignore:
    #     - missing_policy_rule:Blogging::Post#publish
    #
    # `ignore` entries are the keys the report prints under each finding, so a
    # line can be copied straight out of the output.
    class Config
      DEFAULT_FILENAME = ".plutonium-doctor.yml"

      attr_reader :path, :disabled, :ignored

      # @param root [Pathname, String, nil] application root; nil skips file loading
      def self.load(root: default_root, filename: DEFAULT_FILENAME)
        return new if root.nil?

        path = Pathname.new(root).join(filename)
        return new unless path.file?

        data = YAML.safe_load_file(path) || {}
        new(
          path: path,
          disabled: Array(data["disable"]).map(&:to_sym),
          ignored: Array(data["ignore"]).map(&:to_s)
        )
      end

      def self.default_root = defined?(Rails.root) ? Rails.root : nil

      def initialize(path: nil, disabled: [], ignored: [])
        @path = path
        @disabled = disabled.to_set
        @ignored = ignored.to_set
      end

      def disabled?(check_name) = disabled.include?(check_name.to_sym)

      def ignored?(finding) = ignored.include?(finding.key)
    end
  end
end
