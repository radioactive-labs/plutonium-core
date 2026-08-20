# frozen_string_literal: true

module Plutonium
  module Interaction
    module Async
      # The UI configuration for run records.
      #
      # Named +RunDefinition+ rather than +Async::Definition+ because definition
      # lookup is by convention and nothing else: both
      # Plutonium::Resource::Controller#resource_definition and
      # Plutonium::Resource::Controllers::Defineable#resource_definition
      # constantize "#{resource_class}Definition", and
      # Plutonium::Definition::Base.model_class infers the model back out of that
      # same name. A differently-named class would simply never be found.
      #
      # Host apps override per portal the usual way, with
      # +MyPortal::Plutonium::Interaction::Async::RunDefinition+.
      class RunDefinition < Plutonium::Resource::Definition
        # `outcome` rather than `state`: a :continue run that could not apply some
        # of its targets ends as "completed", and a green Completed badge on a run
        # that under-applied is exactly the report an operator must never be given.
        # See Plutonium::Interaction::Async::Run#outcome.
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
            render Plutonium::UI::Interaction::Async::RunProgress.new(resource_record!)
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
              render Plutonium::UI::Interaction::Async::RunProgress.new(resource_record!)
            end
          end

          private

          def progress_poll?
            current_turbo_frame == Plutonium::UI::Interaction::Async::RunProgress.frame_id(resource_record!)
          end
        end

        # The index refreshes itself while any run is still working.
        #
        # ONE frame around the collection, not one per row. A +turbo-frame+ is
        # not in the content model of +tr+, so a frame wrapping a row is hoisted
        # out of the table by the HTML parser before Turbo ever sees it. A frame
        # per CELL parses, but buys one poller per row for a single page.
        #
        # The Stimulus controller sits INSIDE the frame, exactly as
        # {Plutonium::UI::Interaction::Async::RunProgress} places it: a frame
        # navigation replaces the frame's CONTENTS, not the frame element, so a
        # controller on the tag itself could never be removed and the timer
        # would never stop.
        class IndexPage < IndexPage
          include Phlex::Rails::Helpers::TurboFrameTag

          FRAME_ID = "pu_async_runs_index"

          # Answers the frame's poll with the collection ALONE, for the reason
          # spelled out on {ShowPage}: DynaFrameContent already wraps every
          # response in a frame named by the inbound header, so emitting the
          # page would nest the whole thing inside its own frame, and again on
          # the next poll.
          def view_template(&)
            return super unless answering_own_frame?

            DynaFrameContent() do
              render_default_content
            end
          end

          private

          def answering_own_frame? = current_turbo_frame == FRAME_ID

          def render_default_content
            body = proc { div(**poll_attributes) { super() } }
            return body.call if answering_own_frame?

            # `turbo-frame` defaults to `display: inline`.
            turbo_frame_tag(FRAME_ID, class: "block", &body)
          end

          # Absent once nothing is working: the refreshed markup no longer
          # carries the controller, and the timer stops of its own accord. The
          # index needs no equivalent of RunProgress's +finished+ reload — the
          # whole collection is inside this frame, so there are no stale fields
          # beside it to catch up.
          #
          # The URL is the CURRENT one, filters, sort and page included. Polling
          # the bare index would answer page 1 unfiltered and swap that into a
          # frame the operator had scoped to something else.
          def poll_attributes
            return {} unless any_run_in_progress?

            {
              data: {
                controller: "run-progress",
                run_progress_url_value: current_page_url,
                run_progress_interval_value: Plutonium::UI::Interaction::Async::RunProgress::POLL_INTERVAL_MS
              }
            }
          end

          # Asked of the SCOPE rather than the rendered page, through the same
          # door render_running_banner uses. It can only over-poll (an operator
          # reading last month's finished runs while something works elsewhere),
          # never under-poll: a run visible and in progress makes this true.
          def any_run_in_progress?
            authorized_resource_scope(Run, relation: Run.in_progress).exists?
          end
        end
      end
    end
  end
end
