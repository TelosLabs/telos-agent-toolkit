# frozen_string_literal: true

require 'json'
require 'octokit'
require_relative 'issue_body_builder'

module Telos
  module AgentToolkit
    # Creates and manages GitHub issues for production alerts with deduplication,
    # rate limiting, and machine-readable metadata embedding.
    class IssueManager
      class Error < StandardError; end

      LABEL_DEFINITIONS = [
        { 'name' => 'baymax', 'color' => '0ea5e9' },
        { 'name' => 'severity:critical', 'color' => 'b60205' },
        { 'name' => 'severity:error', 'color' => 'd93f0b' },
        { 'name' => 'severity:warning', 'color' => 'fbca04' },
        { 'name' => 'severity:info', 'color' => '0e8a16' },
        { 'name' => 'security:tier-1', 'color' => '0e8a16' },
        { 'name' => 'security:tier-2', 'color' => 'fbca04' },
        { 'name' => 'security:tier-3', 'color' => 'b60205' },
        { 'name' => 'baymax-fix', 'color' => '6366f1' }
      ].freeze

      def initialize(config)
        @config = config
        @repo = config.github_repo
        @client = Octokit::Client.new(access_token: ENV.fetch('GITHUB_TOKEN'))
      end

      def ensure_labels!
        LABEL_DEFINITIONS.each do |label|
          @client.add_label(@repo, label['name'], label['color'])
        rescue Octokit::UnprocessableEntity
          next
        end
      end

      def rate_limited?(max_per_hour)
        return false unless max_per_hour&.positive?

        recent_issue_count >= max_per_hour
      end

      def create_issue(alert:, decision:, fingerprint:, triage_result: nil)
        existing = Fingerprint.duplicate?(client: @client, repo: @repo, fingerprint: fingerprint)
        return handle_duplicate(existing, alert) if existing

        persist_issue(alert: alert, triage_result: triage_result, decision: decision, fingerprint: fingerprint)
      end

      private

      def recent_issue_count
        prefix = @config.github_issue_prefix
        since = (Time.now.utc - 3600).iso8601
        query = "repo:#{@repo} is:issue author:app/github-actions \"#{prefix}\" created:>=#{since}"
        @client.search_issues(query, per_page: 1).total_count
      end

      def handle_duplicate(existing, alert)
        add_duplicate_comment(existing.number, alert)
        { status: :duplicate, issue: existing }
      end

      def persist_issue(alert:, triage_result:, decision:, fingerprint:)
        title = build_title(alert)
        body = IssueBodyBuilder.new(
          alert: alert, triage_result: triage_result, decision: decision, fingerprint: fingerprint
        ).build
        labels = build_labels(alert: alert, triage_result: triage_result, decision: decision)

        ensure_labels!
        issue = @client.create_issue(@repo, title, body, labels: labels)
        { status: :created, issue: issue }
      end

      def build_title(alert)
        prefix = @config.github_issue_prefix
        "#{prefix} #{alert.error_class}: #{alert.error_message.to_s[0, 80]}"
      end

      def build_labels(alert:, triage_result:, decision:)
        labels = [@config.github_issue_prefix.tr('[]', '').strip]
        labels << "severity:#{alert.severity}"
        labels << security_label(triage_result) if triage_result
        labels << 'baymax-fix' if %i[fix fix_with_review].include?(decision.action)
        labels.compact.uniq
      end

      def security_label(triage_result)
        "security:#{triage_result.security_tier.to_s.tr('_', '-')}"
      end

      def add_duplicate_comment(issue_number, alert)
        body = "Duplicate alert detected at #{Time.now.utc.iso8601}.\n" \
               "**Source:** #{alert.source} | **Occurrences:** #{alert.occurrence_count}"
        @client.add_comment(@repo, issue_number, body)
      end
    end
  end
end
