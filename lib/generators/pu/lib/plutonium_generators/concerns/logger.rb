# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    module Logger
      def debug(msg)
        say format_log(msg, :debug), :magenta
      end

      def info(msg)
        say format_log(msg, :info), :blue
      end

      def success(msg)
        say format_log(msg, :success), :green
      end

      def error(msg)
        say format_log(msg, :error), :red
        exit(1)
      end

      def exception(msg, err)
        error "#{msg}\n\n#{err}\n#{err.backtrace.join("\n")}"
      end

      private

      def format_log(msg, _log_level)
        # indentation = ' ' * (log_level.length + 2)
        # "#{log_level}: #{msg}" # .lines.join(indentation)
        msg
      end
    end
  end
end
