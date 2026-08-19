# frozen_string_literal: true

module Plutonium
  module Interaction
    # The UI configuration for run records.
    #
    # Named +AsyncRunDefinition+ rather than +AsyncRuns::Definition+ because definition
    # lookup is by convention and nothing else: both
    # Plutonium::Resource::Controller#resource_definition and
    # Plutonium::Resource::Controllers::Defineable#resource_definition
    # constantize "#{resource_class}Definition", and
    # Plutonium::Definition::Base.model_class infers the model back out of that
    # same name. A differently-named class would simply never be found.
    #
    # Host apps override per portal the usual way, with
    # +MyPortal::Plutonium::Interaction::AsyncRunDefinition+.
    class AsyncRunDefinition < Plutonium::Resource::Definition
      # `outcome` rather than `state`: a :continue run that could not apply some
      # of its targets ends as "completed", and a green Completed badge on a run
      # that under-applied is exactly the report an operator must never be given.
      # See Plutonium::Interaction::AsyncRun#outcome.
      # Only `outcome` is declared. Everything else the policy makes readable is
      # a real column and infers its own type; `outcome` is a method, so it has
      # neither a type to infer nor a badge to infer one from (`state` is a
      # plain string column with an inclusion validation, not a Rails enum).
      #
      # `running` and `completed_with_errors` are coloured explicitly: neither
      # is in the badge component's semantic table, and its fallback is a
      # stable-but-meaningless colour.
      field :outcome, as: :string
      display :outcome, as: :badge,
        colors: {running: :info, completed_with_errors: :warning}
      # Declared for the table too: the index is where an operator scans for the
      # run that did not do what it was asked, and a bare
      # "completed_with_errors" string is the one place that reads worse than
      # the badge.
      column :outcome, as: :badge,
        colors: {running: :info, completed_with_errors: :warning}

      field :target_label, label: "Target type"

      # The details tab, with the live panel above the fields.
      #
      # On the Display rather than the ShowPage: page-level
      # render_before_content sits outside the tablist and outside the modal
      # chrome, so a run opened in a modal would render its progress above the
      # dialog instead of inside it.
      class Display < Display
        private

        def render_before_fields
          render Plutonium::UI::Interaction::AsyncRunProgress.new(resource_record!)
        end
      end

      class ShowPage < ShowPage
        # Answers the progress frame's poll with the panel ALONE.
        #
        # Turbo sends +Turbo-Frame: <id>+ when the frame re-fetches its src, and
        # DynaFrameContent wraps every response in a frame of that name. Falling
        # through to the normal page would therefore return the whole show page
        # wrapped in a frame carrying the progress frame's id — with the panel's
        # own frame nested inside it, under the same id. Turbo would swap the
        # outer one in, and the next poll would nest again.
        def view_template(&)
          return super unless progress_poll?

          DynaFrameContent do
            render Plutonium::UI::Interaction::AsyncRunProgress.new(resource_record!)
          end
        end

        private

        def progress_poll?
          current_turbo_frame == Plutonium::UI::Interaction::AsyncRunProgress.frame_id(resource_record!)
        end
      end
    end
  end
end
