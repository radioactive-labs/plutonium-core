# frozen_string_literal: true

require "csv"

# A CSV import that checks the WHOLE file before creating anything: the
# browser-drivable example of an async run's pre_check. A file with a bad row
# is rejected with every problem listed, and no task is created.
class ImportTasksInteraction < ::ResourceInteraction
  presents label: "Import tasks (async)",
    icon: Phlex::TablerIcons::Upload

  attribute :import_file
  input :import_file, as: :file

  validates :import_file, presence: true

  async do
    def pre_check
      table = read_table
      # reject records a problem and carries on, so return explicitly where
      # nothing after it would make sense.
      unless table.headers.include?("title")
        reject "missing column: title"
        return
      end

      rows = rows_of(table)
      if rows.empty?
        reject "the file has no rows to import"
        return
      end

      rows.each do |row, line|
        reject "line #{line}: title is missing" if row["title"].blank?
        unless row["status"].blank? || Task::IMPORTABLE_STATUSES.include?(row["status"])
          reject "line #{line}: unknown status #{row["status"].inspect}"
        end
      end
    rescue CSV::MalformedCSVError => e
      reject "the file is not valid CSV: #{e.message}"
    end

    # All or nothing: a failure partway, or a resume after a reap (an opaque
    # perform re-runs from scratch), cannot leave a partial or duplicated import.
    def perform
      Task.transaction do
        rows_of(read_table).each do |row, _line|
          Task.create!(title: row["title"], status: row["status"].presence || "todo")
        end
      end
    end

    private

    # Read whole, as UTF-8 without Excel's byte-order mark: the stored file comes
    # back as binary, and a BOM would otherwise become part of the first header.
    def read_table
      text = attachment(:import_file).download.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF")
      CSV.parse(text, headers: true)
    end

    # Line numbers as a spreadsheet shows them: the header is line 1. Blank
    # lines are skipped without shifting the numbers of the rows after them.
    def rows_of(table)
      table.each.with_index(2).reject { |row, _line| row.fields.all?(&:blank?) }
    end
  end
end
