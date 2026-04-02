# frozen_string_literal: true

require 'digest/sha1'

module Telos
  module AgentToolkit
    # Generates SHA1 fingerprints for alert deduplication via GitHub issue search.
    module Fingerprint
      module_function

      COMMENT_PREFIX = 'toolkit:fingerprint:sha1:'

      # Generate SHA1 fingerprint from canonical key fields
      def generate(source:, error_class:, app_name:)
        Digest::SHA1.hexdigest("#{source}::#{error_class}::#{app_name}")
      end

      # Embed fingerprint as HTML comment for GitHub issues
      def to_html_comment(fingerprint)
        "<!-- #{COMMENT_PREFIX}#{fingerprint} -->"
      end

      # Extract fingerprint from issue body
      def from_html_comment(body)
        match = body&.match(/<!-- #{Regexp.escape(COMMENT_PREFIX)}(\h{40}) -->/)
        match&.captures&.first
      end

      # Search GitHub for existing issue with this fingerprint
      def duplicate?(client:, repo:, fingerprint:)
        query = "repo:#{repo} is:issue is:open in:body #{COMMENT_PREFIX}#{fingerprint}"
        result = client.search_issues(query, per_page: 1)
        return nil unless result.total_count.positive? # rubocop:disable Style/ReturnNilInPredicateMethodDefinition

        result.items.first
      end
    end
  end
end
