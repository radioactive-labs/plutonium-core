# frozen_string_literal: true

module PlutoniumGenerators
  # A drop-in replacement for TTY::Prompt that raises on any interactive method.
  # Used when --no-interactive is passed or when there's no TTY (e.g., tests, CI).
  class NonInteractivePrompt
    def select(question, choices = nil, **)
      raise Thor::Error, "Interactive prompt not available: #{question}. Provide the required option explicitly."
    end

    def ask(question, **)
      raise Thor::Error, "Interactive prompt not available: #{question}. Provide the required option explicitly."
    end

    def yes?(question, **)
      raise Thor::Error, "Interactive prompt not available: #{question}. Provide the required option explicitly."
    end

    def no?(question, **)
      raise Thor::Error, "Interactive prompt not available: #{question}. Provide the required option explicitly."
    end

    def multi_select(question, **)
      raise Thor::Error, "Interactive prompt not available: #{question}. Provide the required option explicitly."
    end
  end
end
