# frozen_string_literal: true

return unless Rails.env.development?

# Taken from https://gist.github.com/kyrylo/3d90f7a656d1a0accf244b8f1d25999b?permalink_comment_id=5264120#gistcomment-5264120

module ColorizedLogger
  %i[debug info warn error fatal unknown].each do |level|
    color = case level
    when :debug then "\e[0;36m"  # Cyan text
    when :info then "\e[0;32m"  # Green text
    when :warn then "\e[1;33m"  # Yellow text
    when :error, :fatal then "\e[1;31m"  # Red text
    else "\e[0m"  # Terminal default
    end

    define_method(level) do |progname = nil, &block|
      super(color + (progname || (block && block.call)).to_s + "\e[0m")
    end
  end
end
Rails.logger.extend(ColorizedLogger)
