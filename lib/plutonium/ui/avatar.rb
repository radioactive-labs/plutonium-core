# frozen_string_literal: true

require "digest"
require "cgi"

module Plutonium
  module UI
    # Renders a profile/avatar image for a subject.
    #
    #   Avatar(user)                     # Navii fallback seeded from the record
    #   Avatar(user, src: :photo)        # user.photo if present, else Navii fallback
    #   Avatar(user, src: user.photo)    # pass the attachment/uploader/URL directly
    #   Avatar("acme-team")              # a String subject is a deterministic seed
    #   Avatar("https://.../p.png")      # a URL-shaped subject is shown as the image
    #   Avatar(src: "https://.../p.png") # a bare image, no subject/fallback
    #
    # The positional +subject+ is the identity the fallback is derived from: a
    # record or a String, hashed to an opaque, PII-free seed. As a convenience, a
    # URL-shaped String subject is treated as +src+ (the image) instead.
    # +src+ is the image to show and may be:
    # - a Symbol naming a method on the subject (e.g. +:avatar+ -> +subject.avatar+).
    #   This is a contract: the subject must respond to it (raises NoMethodError
    #   otherwise), so only use a Symbol +src+ with a record subject.
    # - an ActiveStorage attachment, active_shrine/Shrine uploader, or URL String
    #
    # Resolution order: the resolved +src+, then a Navii avatar seeded from the
    # subject, then a generic user icon when there is nothing to show.
    class Avatar < Plutonium::UI::Component::Base
      # Pixel dimensions per semantic size, plus the matching Tailwind width/height
      # utilities (needed because the preflight resets `img { height: auto }`, so
      # width/height attributes alone don't pin the rendered size).
      SIZES = {xs: 24, sm: 32, md: 40, lg: 48, xl: 64}.freeze
      SIZE_CLASSES = {xs: "w-6 h-6", sm: "w-8 h-8", md: "w-10 h-10", lg: "w-12 h-12", xl: "w-16 h-16"}.freeze

      # Resolve an image value to a URL string. Supports:
      # - ActiveStorage attachments -> helpers.url_for (they aren't routable via #url)
      # - active_shrine / other ActiveStorage-style wrappers -> value.url
      # - Bare Shrine::UploadedFile, CarrierWave, etc. (respond to :url) -> value.url
      # - Plain URL strings ("https://..." or "/uploads/...")
      #
      # Exposed as a module method so collaborators (e.g. Grid::Card) can reuse
      # the resolution without instantiating the component.
      def self.resolve_image_src(value, helpers = nil)
        return nil if value.nil?

        # ActiveStorage is the only supported source that must go through Rails
        # routing rather than its own #url. It has to be matched *before* the
        # generic attached?/url checks, because ActiveStorage-compatible wrappers
        # (e.g. active_shrine) respond to BOTH attached? and url, and those should
        # resolve via their own #url instead.
        if active_storage_attachment?(value)
          return value.attached? ? helpers&.url_for(value) : nil
        end

        if value.respond_to?(:attached?)  # active_shrine & other AS-style wrappers
          value.attached? ? value.url : nil
        elsif value.respond_to?(:url)     # bare Shrine::UploadedFile, CarrierWave, ...
          value.url
        elsif value.is_a?(String) && value.start_with?("http", "/")
          value
        end
      rescue ArgumentError, URI::InvalidURIError
        nil
      end

      def self.active_storage_attachment?(value)
        defined?(ActiveStorage::Attached) && value.is_a?(ActiveStorage::Attached)
      end
      private_class_method :active_storage_attachment?

      def initialize(subject = nil, src: nil, size: :md, alt: nil, **attributes)
        # A URL-shaped positional subject is really an image, not an identity:
        # route it to src so Avatar("https://…/p.png") shows the image rather
        # than hashing the URL into a seed.
        if src.nil? && subject.is_a?(String) && subject.start_with?("http", "/")
          src = subject
          subject = nil
        end

        @subject = subject
        @src = src
        @size = size
        @alt = alt
        @attributes = attributes
      end

      def view_template
        url = resolved_src || navii_url

        if url
          img(
            src: url, alt: alt_text.to_s, width: pixel_size, height: pixel_size, loading: "lazy",
            **sized_attributes("rounded-full object-cover bg-[var(--pu-surface-alt)] shrink-0")
          )
        else
          div(**sized_attributes("rounded-full bg-[var(--pu-surface-alt)] text-[var(--pu-text-muted)] flex items-center justify-center shrink-0")) do
            render Phlex::TablerIcons::User.new(class: "w-2/3 h-2/3")
          end
        end
      end

      private

      # Merge the component's base classes, the size class, and the caller's class;
      # add an inline dimension style for raw-pixel (Integer) sizes.
      def sized_attributes(base)
        attrs = @attributes.dup
        attrs[:class] = tokens(base, size_class, attrs.delete(:class))
        attrs[:style] = [size_style, attrs[:style]].compact.join("; ") if size_style
        attrs
      end

      def pixel_size
        @size.is_a?(Symbol) ? SIZES.fetch(@size) : @size
      end

      def size_class
        @size.is_a?(Symbol) ? SIZE_CLASSES.fetch(@size) : nil
      end

      def size_style
        "width: #{@size}px; height: #{@size}px" unless @size.is_a?(Symbol)
      end

      def resolved_src
        value = image_src_value
        return nil if value.nil?

        # Only reach for the Rails helper proxy when we have an attachment-style
        # source (ActiveStorage needs helpers.url_for; the resolver ignores it
        # for active_shrine and other #url-bearing sources).
        resolver_helpers = value.respond_to?(:attached?) ? helpers : nil
        self.class.resolve_image_src(value, resolver_helpers)
      end

      # A Symbol src names a method on the subject (e.g. :avatar -> subject.avatar);
      # anything else is the attachment/uploader/URL itself.
      def image_src_value
        @src.is_a?(Symbol) ? @subject&.public_send(@src) : @src
      end

      def navii_url
        seed = navii_seed
        return nil unless seed

        host = Plutonium.configuration.navii_host_url
        "#{host}/avatar/#{CGI.escape(seed)}?size=#{pixel_size}"
      end

      # The value sent to Navii is ALWAYS a hash of the subject's identity, so no
      # plaintext (model names, ids, emails, or caller-provided seed strings) ever
      # reaches the external service. Determinism is preserved: same identity ->
      # same hash -> same avatar.
      def navii_seed
        identity = subject_identity
        return nil unless identity

        Digest::SHA256.hexdigest(identity)[0, 16]
      end

      # Stable identity string for the subject: a String subject verbatim, or
      # "Class:id" for a record. Hashed by #navii_seed before it leaves the app.
      def subject_identity
        case @subject
        when nil then nil
        when String then @subject
        else "#{@subject.class.name}:#{@subject.id}" if @subject.respond_to?(:id) && @subject.id.present?
        end
      end

      def alt_text
        return @alt if @alt

        case @subject
        when nil then nil
        when String then @subject
        else helpers&.display_name_of(@subject)
        end
      end
    end
  end
end
