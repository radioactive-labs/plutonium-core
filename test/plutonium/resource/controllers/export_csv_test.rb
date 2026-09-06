# frozen_string_literal: true

require "test_helper"
require "csv"
require "ostruct"

class Plutonium::Resource::Controllers::ExportCsvTest < Minitest::Test
  # Minimal in-memory relation that responds to find_each like an
  # ActiveRecord::Relation, so the concern can be exercised without a DB.
  class FakeRelation
    def initialize(rows) = @rows = rows
    def find_each = @rows.each { |r| yield r }
  end

  class FakePolicy
    def initialize(attrs) = @attrs = attrs
    def send_with_report(method) = public_send(method)
    def permitted_attributes_for_export = @attrs
  end

  def build_controller(rows:, exportable:, defined_exports: {}, params: {}, all_rows: nil)
    controller = Class.new do
      def self.before_action(*) = nil
      def self.skip_verify_current_authorized_scope(*) = nil

      include Plutonium::Resource::Controllers::ExportCsv

      attr_accessor :current_policy, :current_definition, :resource_class
      attr_accessor :authorized_to, :params
      attr_writer :relation, :authorized_scope

      def authorize_current!(_subject, to:) = (@authorized_to = to)

      def filtered_resource_collection = @relation

      def current_authorized_scope = @authorized_scope
    end.new

    controller.relation = FakeRelation.new(rows)
    controller.authorized_scope = FakeRelation.new(all_rows || rows)
    controller.params = ActiveSupport::HashWithIndifferentAccess.new(params)
    controller.current_policy = FakePolicy.new(exportable)
    controller.current_definition = OpenStruct.new(defined_exports: defined_exports)
    controller.resource_class = build_resource_class
    # The real controller reaches view helpers (resource_name_plural for the
    # filename, display_name_of for associations) via the `helpers` proxy.
    helper_obj = Object.new.extend(Plutonium::Helpers::DisplayHelper)
    controller.define_singleton_method(:helpers) { helper_obj }
    controller
  end

  # Parses the CSV produced by the controller's line enumerator.
  def export_table(controller)
    CSV.parse(controller.send(:export_csv_lines).to_a.join)
  end

  # A stand-in resource class: primary_key "id" + model_name.human, which
  # resource_name_plural pluralizes into the filename ("Widget" → "widgets").
  def build_resource_class
    Class.new do
      def self.primary_key = "id"
      def self.model_name = OpenStruct.new(human: "Widget")

      # The export preloads the associations its columns render, so it asks the
      # resource class what those are. A real resource gets these from
      # Plutonium::Resource::Record::FieldNames; this double has none, which is
      # what keeps `includes` off the FakeRelation below.
      def self.belongs_to_association_field_names = []

      def self.has_one_association_field_names = []

      def self.has_many_association_field_names = []

      def self.has_one_attached_field_names = []

      def self.has_many_attached_field_names = []
    end
  end

  Row = Struct.new(:id, :name, :status)

  def test_streams_header_and_one_line_per_record
    controller = build_controller(
      rows: [Row.new(1, "Alpha", "active"), Row.new(2, "Beta", "draft")],
      exportable: [:name, :status]
    )
    table = export_table(controller)

    assert_equal %w[Id Name Status], table[0]
    assert_equal [["1", "Alpha", "active"], ["2", "Beta", "draft"]], table[1..]
  end

  def test_id_is_always_the_first_column_even_when_not_exportable
    controller = build_controller(
      rows: [Row.new(7, "Gamma", "active")],
      exportable: [:name] # no :id
    )
    table = export_table(controller)

    assert_equal %w[Id Name], table[0]
    assert_equal ["7", "Gamma"], table[1]
  end

  def test_id_is_not_duplicated_when_already_exportable
    controller = build_controller(
      rows: [Row.new(7, "Gamma", "active")],
      exportable: [:id, :name]
    )
    assert_equal %w[Id Name], export_table(controller)[0]
  end

  def test_export_block_overrides_cell_value_and_label_overrides_header
    controller = build_controller(
      rows: [Row.new(1, "Alpha", "active")],
      exportable: [:name],
      defined_exports: {
        name: {options: {label: "Title"}, block: ->(record) { record.name.upcase }}
      }
    )
    table = export_table(controller)

    assert_equal %w[Id Title], table[0]
    assert_equal ["1", "ALPHA"], table[1]
  end

  def test_filename_uses_pluralized_model_name_and_date
    controller = build_controller(rows: [], exportable: [:name])
    assert_match(/\Awidgets_\d{4}-\d{2}-\d{2}\.csv\z/, controller.send(:export_csv_filename))
  end

  # CSV/formula injection: a cell beginning with = + - @ (or a leading
  # tab/CR) is neutralized with a leading single quote so spreadsheet apps
  # import it as literal text rather than executing it.
  def test_neutralizes_formula_injection_in_cell_values
    controller = build_controller(
      rows: [Row.new(1, "=HYPERLINK(\"http://evil\")", "+1")],
      exportable: [:name, :status]
    )
    row = export_table(controller)[1]

    assert_equal "'=HYPERLINK(\"http://evil\")", row[1]
    assert_equal "'+1", row[2]
  end

  # Full-width (double-byte) variants of the formula initiators — ＝ ＋ － ＠
  # (U+FF1D/FF0B/FF0D/FF20) — are interpreted as formulas in East Asian
  # locales (e.g. Japanese Excel; see OWASP CSV Injection guidance). They must
  # be neutralized just like their ASCII counterparts, but the *original*
  # (un-normalized) value is what carries the quote prefix so legitimate
  # full-width content is preserved verbatim.
  def test_neutralizes_full_width_formula_characters
    controller = build_controller(rows: [], exportable: [:name])

    %w[＝ ＋ － ＠].each do |char|
      payload = "#{char}1+1"
      assert_equal "'#{payload}", controller.send(:neutralize_csv_formula, payload),
        "full-width #{char} should be neutralized like its ASCII counterpart"
    end
  end

  # The quote is prefixed to the original string, NOT the NFKC-normalized one,
  # so full-width content is preserved verbatim (only a defensive `'` is added).
  def test_neutralize_preserves_original_full_width_content_verbatim
    controller = build_controller(rows: [], exportable: [:name])
    payload = "＝cmd|' /C calc'!A0"
    neutralized = controller.send(:neutralize_csv_formula, payload)

    assert_equal "'#{payload}", neutralized
    refute_equal "'=cmd|' /C calc'!A0", neutralized,
      "must not replace the full-width char with its ASCII form in the output"
  end

  # No regression: ASCII initiators and leading tab/CR are still neutralized,
  # and non-string / empty values are still handled without raising.
  def test_still_neutralizes_ascii_and_handles_non_string_values
    controller = build_controller(rows: [], exportable: [:name])

    ["=", "+", "-", "@", "\t", "\r"].each do |char|
      payload = "#{char}1"
      assert_equal "'#{payload}", controller.send(:neutralize_csv_formula, payload),
        "ASCII #{char.inspect} should still be neutralized"
    end
    assert_equal "", controller.send(:neutralize_csv_formula, "")
    assert_equal "'-5", controller.send(:neutralize_csv_formula, -5)
    assert_equal "", controller.send(:neutralize_csv_formula, nil)
  end

  # No false positives: ordinary ASCII and legitimate full-width Japanese
  # content (katakana, full-width digits/letters) are left untouched.
  def test_leaves_legitimate_full_width_and_plain_content_untouched
    controller = build_controller(rows: [], exportable: [:name])

    ["Alpha", "100", "hello world", "ア", "１２３", "カタカナ", "Ａｌｐｈａ"].each do |value|
      assert_equal value, controller.send(:neutralize_csv_formula, value),
        "#{value.inspect} should not gain a spurious quote prefix"
    end
  end

  def test_leaves_ordinary_values_untouched
    controller = build_controller(rows: [Row.new(1, "Alpha", "active")], exportable: [:name])
    assert_equal ["1", "Alpha"], export_table(controller)[1]
  end

  # A column that is neither an `export` block nor a real attribute renders the
  # INVALID_COLUMN placeholder instead of raising NoMethodError mid-stream.
  def test_unknown_attribute_renders_invalid_column_placeholder
    controller = build_controller(
      rows: [Row.new(1, "Alpha", "active")],
      exportable: [:name, :nonexistent]
    )
    table = export_table(controller)

    assert_equal %w[Id Name Nonexistent], table[0]
    assert_equal ["1", "Alpha", "<<invalid column>>"], table[1]
  end

  def test_authorize_export_csv_checks_export_csv_policy
    controller = build_controller(rows: [], exportable: [:name])
    controller.send(:authorize_export_csv!)
    assert_equal :export_csv?, controller.authorized_to
  end

  # Two exports: the default honors the current query (filtered scope),
  # while ?all=1 bypasses it and streams the entire authorized scope.

  def test_default_export_uses_the_filtered_collection
    controller = build_controller(
      rows: [Row.new(1, "Filtered", "active")],
      all_rows: [Row.new(9, "Everything", "active")],
      exportable: [:name]
    )
    assert_equal ["Filtered"], export_table(controller)[1..].map { |row| row[1] }
  end

  def test_export_all_uses_the_full_authorized_scope
    controller = build_controller(
      rows: [Row.new(1, "Filtered", "active")],
      all_rows: [Row.new(9, "Everything", "active"), Row.new(10, "More", "active")],
      exportable: [:name],
      params: {all: "1"}
    )
    assert_equal ["Everything", "More"], export_table(controller)[1..].map { |row| row[1] }
  end

  def test_export_all_filename_is_suffixed
    controller = build_controller(rows: [], exportable: [:name], params: {all: "1"})
    assert_match(/\Awidgets_all_\d{4}-\d{2}-\d{2}\.csv\z/, controller.send(:export_csv_filename))
  end
end
