# frozen_string_literal: true

module Plutonium
  module Rbac
    # Wildcard-aware matching of a key against a set of granted keys.
    #
    # Granted keys may be exact ("blogging/post.read"), a resource wildcard
    # ("blogging/post.*") or global ("*"). The key being checked may itself be
    # a wildcard (the escalation guard checks a role's keys against the actor's),
    # in which case only an equal or broader wildcard grants it.
    module Matcher
      module_function

      def grants?(granted, key)
        return true if granted.include?("*") || granted.include?(key)
        return false if key == "*"

        resource_wildcard = "#{key.split(".").first}.*"
        return false if key == resource_wildcard

        granted.include?(resource_wildcard)
      end
    end
  end
end
