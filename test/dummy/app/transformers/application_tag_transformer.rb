# frozen_string_literal: true

module ApplicationTagTransformer
  module_function

  # @param [String|Array<String>] tags
  def parse_tags(tags)
    tags = recreate_string(tags) if tags.is_a?(Array)
    tags.split(separator).map(&:strip)
  end

  # Recreate a string from an array of tags
  # @param [Array<String>] tags
  # @return [String]
  def recreate_string(tags)
    tags.join(separator)
  end

  # @return [String]
  def separator
    ","
  end
end
