# frozen_string_literal: true

require 'json'

module Telos
  module AgentToolkit
    # Builds the Markdown body for GitHub issues including human-readable sections
    # and machine-readable metadata embedded as HTML comments.
    class IssueBodyBuilder
      def initialize(alert:, triage_result:, decision:, fingerprint:)
        @alert = alert
        @triage_result = triage_result
        @decision = decision
        @fingerprint = fingerprint
      end

      def build
        [
          human_readable_section,
          metadata_comment,
          Fingerprint.to_html_comment(@fingerprint)
        ].join("\n\n")
      end

      private

      def human_readable_section
        parts = alert_header
        parts.concat(triage_section) if @triage_result
        parts.concat(decision_section)
        parts.join("\n")
      end

      def alert_header
        [
          summary_line,
          "**Error:** `#{@alert.error_class}`",
          '',
          '### Error Message',
          @alert.error_message.to_s
        ]
      end

      def summary_line
        "**Source:** #{@alert.source} | **Severity:** #{@alert.severity} | " \
          "**Occurrences:** #{@alert.occurrence_count}"
      end

      def decision_section
        ['', '### Decision', "**Action:** #{@decision.action} | **Reason:** #{@decision.reason}"]
      end

      def triage_section
        parts = ['', '### Root Cause Analysis', @triage_result.root_cause.to_s, '']
        parts << triage_confidence_line
        parts.concat(affected_files_lines)
        parts.concat(suggested_fix_lines)
        parts
      end

      def triage_confidence_line
        "**Confidence:** #{(@triage_result.confidence * 100).round}% | " \
          "**Security Tier:** #{@triage_result.security_tier} | " \
          "**Fixable:** #{@triage_result.fixable ? 'Yes' : 'No'} | " \
          "**Category:** #{@triage_result.category}"
      end

      def affected_files_lines
        return [] unless @triage_result.affected_files&.any?

        ['', '### Affected Files'] + @triage_result.affected_files.map { |f| "- `#{f}`" }
      end

      def suggested_fix_lines
        return [] unless @triage_result.suggested_fix

        ['', '### Suggested Fix', @triage_result.suggested_fix]
      end

      def metadata_comment
        metadata = alert_metadata
        metadata.merge!(triage_metadata) if @triage_result
        "<!-- toolkit:metadata:#{JSON.generate(metadata)} -->"
      end

      def alert_metadata
        source_metadata.merge(
          fingerprint: @fingerprint,
          decision_action: @decision.action.to_s,
          created_at: Time.now.utc.iso8601
        )
      end

      def source_metadata
        {
          source: @alert.source,
          error_class: @alert.error_class,
          severity: @alert.severity.to_s,
          occurrence_count: @alert.occurrence_count,
          incident_id: @alert.incident_id,
          revision: @alert.revision
        }
      end

      def triage_metadata
        {
          confidence: @triage_result.confidence,
          security_tier: @triage_result.security_tier.to_s,
          fixable: @triage_result.fixable,
          affected_files: @triage_result.affected_files,
          category: @triage_result.category.to_s,
          data_related: @triage_result.data_related
        }
      end
    end
  end
end
