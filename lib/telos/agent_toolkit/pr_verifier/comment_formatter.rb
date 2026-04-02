# frozen_string_literal: true

module Telos
  module AgentToolkit
    class PrVerifier
      # Formats verification results into a Markdown comment for the PR.
      class CommentFormatter
        NO_LINKED_ISSUES = "## Baymax Verification\n\n" \
                           'No linked issues found. Add `Fixes #N` to the PR ' \
                           'description or commit messages to enable verification.'

        ICONS = { pass: 'PASS', fail: 'FAIL' }.freeze

        def self.no_linked_issues
          NO_LINKED_ISSUES
        end

        def self.format(results)
          lines = ["## Baymax Verification\n"]
          results.each { |r| lines.concat(single_result(r)) }
          lines.join("\n")
        end

        def self.single_result(result)
          icon = ICONS.fetch(result[:status], 'WARN')
          lines = ["### #{icon} Issue ##{result[:issue]}"]
          lines << result[:message] if result[:message]
          lines.concat(scope_creep_lines(result[:scope_creep]))
          lines << ''
          lines
        end

        def self.scope_creep_lines(scope_creep)
          return [] unless scope_creep&.any?

          lines = ["\n**Scope creep detected** -- these files aren't in the issue's affected files:"]
          scope_creep.each { |f| lines << "- `#{f}`" }
          lines
        end

        private_class_method :single_result, :scope_creep_lines
      end
    end
  end
end
