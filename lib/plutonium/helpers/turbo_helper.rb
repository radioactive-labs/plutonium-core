module Plutonium
  module Helpers
    module TurboHelper
      def current_turbo_frame
        request.headers["Turbo-Frame"]
      end

      # True when the request is rendered inside any turbo frame.
      def in_frame? = current_turbo_frame.present?

      # True when the request is rendered inside either modal frame
      # (primary or secondary).
      def in_modal? = Plutonium::MODAL_FRAMES.include?(current_turbo_frame)

      # True when the request is rendered inside the secondary (stacked)
      # modal frame specifically.
      def in_secondary_modal? = current_turbo_frame == Plutonium::REMOTE_MODAL_SECONDARY_FRAME

      # True when this show request was opened from a kanban card in the modal
      # frame — the card tags its show URL with KANBAN_MODAL_PARAM. Gated on
      # in_modal? so a stray param on a full-page show never hides metadata.
      # Lets the show page drop the metadata rail for kanban cards specifically,
      # leaving regular show modals (and full-page shows) untouched.
      def in_kanban_modal? = in_modal? && params[Plutonium::KANBAN_MODAL_PARAM].present?

      # Returns a turbo-frame-scoped element id. Two identically-named forms
      # can be on the page simultaneously (e.g. a primary modal opens a
      # secondary modal, each rendering an `id="resource-form"`). When the
      # server later replies with `turbo_stream.replace("resource-form", ...)`,
      # Turbo would pick the FIRST element matching the id — which is rarely
      # the one the user actually submitted. Append a frame suffix so each
      # frame's form has a unique id and the controller can target precisely.
      #
      # @param base [String, Symbol] the base id
      # @return [String] the scoped id (no suffix outside any modal frame)
      def turbo_scoped_dom_id(base)
        base = base.to_s
        case current_turbo_frame
        when Plutonium::REMOTE_MODAL_FRAME then "#{base}-primary"
        when Plutonium::REMOTE_MODAL_SECONDARY_FRAME then "#{base}-secondary"
        else base
        end
      end
    end
  end
end
