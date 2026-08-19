# frozen_string_literal: true

module Plutonium
  module Interaction
    module Async
      # Authorization for run records themselves.
      #
      # Named +RunPolicy+ rather than +Policy+ so ActionPolicy's ordinary
      # inference finds it: +INFER_FROM_CLASS+ looks for "#{record_class}Policy",
      # and Plutonium's STI fallback looks for "#{base_class}Policy" — which is
      # what routes a +TestPostRun+ (or any host subclass) to this one policy
      # without every subclass declaring anything.
      #
      # == Read-only
      #
      # A run is the record of something that already happened. There is nothing
      # to create through a form (a run is born from a dispatching interaction,
      # which has its own policy), nothing to edit that would not be rewriting the
      # audit trail, and deleting one destroys the only report of what a bulk
      # action actually did. The four write predicates are therefore hard +false+
      # rather than inherited defaults — subclasses can still open them, but they
      # have to say so.
      #
      # == Scope
      #
      # Nothing is declared here. The base policy's +relation_scope+ already calls
      # +default_relation_scope+, which applies +Run.associated_with(entity_scope)+
      # — and that scope filters on the tenant the run RECORDED at dispatch (see
      # Run). Re-declaring the macro to repeat that filter by hand would add a
      # second, drifting definition of the same rule; declaring it as a
      # +def relation_scope+ instance method would be worse still, since
      # +apply_scope+ never calls one (Plutonium::Resource::Policy.method_added
      # raises on that mistake at class load).
      class RunPolicy < Plutonium::Resource::Policy
        def read? = true

        def create? = false

        def update? = false

        def destroy? = false

        # Deliberately NOT the autodetected column list.
        #
        # +options+ is arbitrary JSON copied from the dispatching interaction's
        # validated inputs — reasons, notes, recipient lists, whatever the author
        # declared. The policy that governed who could SUBMIT those values was the
        # interaction's; the set of people who can READ this run is different and
        # wider (in a tenant portal, everyone in the tenant). Autodetection would
        # quietly hand the second set the first set's input, so the readable
        # attributes are enumerated instead, and +options+ is not among them.
        #
        # +target_ids+ is out for the same reason at one remove: it is a list of
        # primary keys that were never filtered through the target resource's own
        # policy for THIS reader.
        # +outcome+ stands in for +state+, and +state+ is deliberately absent: the
        # two differ only for a run that completed having failed some of its
        # targets, and that is precisely the case where the raw column reads
        # "completed" and tells the reader the opposite of what happened.
        #
        # +errors_log+ is absent because the progress panel renders it as a list —
        # the raw JSON column beside it would be the same report twice, once
        # unreadably.
        def permitted_attributes_for_read
          %i[
            type outcome progress_done progress_total
            target_label initiator started_at finished_at created_at
          ]
        end

        # The show page drops the progress COUNTERS, for the reason errors_log
        # is absent above: the panel already renders them, as "5 of 5 targets
        # (100%)" over a bar. Two renderings of one number is the same report
        # twice — and they disagree, because only the panel is inside the polled
        # frame. A page that says "Completed" and "0 done" at once is worse than
        # either alone.
        #
        # The INDEX keeps them. There is no progress bar in a table row, so the
        # counters are the only progress it can show.
        def permitted_attributes_for_show
          permitted_attributes_for_read - %i[progress_done progress_total]
        end
      end
    end
  end
end
