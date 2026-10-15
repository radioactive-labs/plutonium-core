module Plutonium
  module Interaction
    module Response
      # Represents a redirect response.
      #
      # This class is used to perform redirects as a result of an interaction.
      class Redirect < Base
        private

        # Executes the redirect response.
        #
        # @param controller [ActionController::Base] The controller instance.
        # @return [void]
        def execute(controller)
          # Capture the instance variables before entering instance_eval
          redirect_args = @args
          redirect_options = @options

          controller.instance_eval do
            # Preserve the request format unless explicitly specified.
            #
            # Skipped for a target that is ALREADY A URL. There is nothing to
            # merge a format into, and url_for takes exactly one argument — so
            # appending the options hash raises ArgumentError rather than
            # producing a formatted URL. A caller handing over a complete URL has
            # already decided what it points at.
            #
            # Also skipped for a turbo-stream request: it is answered below with a
            # visit, and a visit wants the page, not a .turbo_stream URL.
            fully_formed_url = redirect_args.size == 1 && redirect_args.first.is_a?(String)

            url_options = redirect_args.last.is_a?(Hash) ? redirect_args.last : {}
            if !fully_formed_url && !url_options.key?(:format) && !request.format.symbol.in?(%i[html turbo_stream])
              url_options = url_options.merge(format: request.format.symbol)
              redirect_args = [*redirect_args[0...-1], url_options] if redirect_args.last.is_a?(Hash)
              redirect_args = [*redirect_args, url_options] unless redirect_args.last.is_a?(Hash)
            end

            url = fully_formed_url ? redirect_args.first : url_for(*redirect_args)

            respond_to do |format|
              # Answered with a stream action wherever the form lives, the way
              # every other Plutonium success path answers a turbo-stream post.
              # A plain redirect_to here is followed by fetch and its page
              # rendered into whatever frame submitted the form.
              #
              # turbo_stream_redirect is a client-side visit, so it skips the
              # open-redirect check redirect_to applies. It is applied here the
              # same way, with redirect_to's own default for allow_other_host:
              # resolved up front from raise_on_open_redirects before Rails 8.1,
              # left nil from 8.1 on, where the check resolves it and nil also
              # drives action_on_open_redirect (:log / :notify).
              format.turbo_stream do
                allow_other_host = redirect_options.fetch(:allow_other_host) do
                  _allow_other_host if ActionPack.gem_version < Gem::Version.new("8.1")
                end
                _enforce_open_redirect_protection(url, allow_other_host:)
                render turbo_stream: helpers.turbo_stream_redirect(url)
              end

              format.any { redirect_to(url, **redirect_options) }
            end
          end
        end
      end
    end
  end
end
