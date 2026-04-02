# frozen_string_literal: true

require 'octokit'

module Telos
  module AgentToolkit
    # Posts agent-triggering comments on GitHub issues to assign AI coding agents
    # (Claude, Copilot, Cursor, OpenCode) for automated fix generation.
    class AgentAssigner
      class Error < StandardError; end

      SUPPORTED_AGENTS = %w[claude copilot cursor opencode].freeze

      AGENT_PREFIXES = {
        'claude' => '@claude',
        'copilot' => '@copilot',
        'cursor' => '@cursor',
        'opencode' => '/opencode'
      }.freeze

      def initialize(config)
        @config = config
        @repo = config.github_repo
        @agent = config.raw.dig('auto_assign', 'agent') || 'claude'
        @token_env = config.raw.dig('auto_assign', 'token_env') || 'AGENT_ASSIGN_TOKEN'
        @client = Octokit::Client.new(access_token: resolve_token)
      end

      def assign(issue_number:, alert:, triage_result:)
        unless SUPPORTED_AGENTS.include?(@agent)
          warn "[toolkit] Unknown agent '#{@agent}', skipping assignment"
          return false
        end

        comment = build_comment(issue_number: issue_number, alert: alert, triage_result: triage_result)
        @client.add_comment(@repo, issue_number, comment)
        true
      rescue Octokit::NotFound => e
        warn "[toolkit] Agent assignment failed for issue ##{issue_number}: #{e.message}"
        false
      end

      private

      def resolve_token
        ENV[@token_env] || ENV['GITHUB_TOKEN'] || ''
      end

      def build_comment(issue_number:, alert:, triage_result:)
        prefix = AGENT_PREFIXES.fetch(@agent)
        prompt = agent_prompt(triage_result)
        context = build_context(alert, triage_result)

        [prefix, prompt, '', "Fixes ##{issue_number}", '', context].join("\n")
      end

      def agent_prompt(triage_result)
        parts = ['Analyze and fix this production error.']
        parts << "The root cause analysis suggests: #{triage_result.root_cause}" if triage_result
        if triage_result&.affected_files&.any?
          parts << "Focus on these files: #{triage_result.affected_files.join(', ')}"
        end
        parts << 'Open a PR with the fix when done.'
        " #{parts.join(' ')}"
      end

      def build_context(alert, triage_result)
        lines = alert_context(alert)
        lines.concat(triage_context(triage_result)) if triage_result
        lines.join("\n")
      end

      def alert_context(alert)
        lines = ['Context:']
        lines << "- error_class: #{alert.error_class}"
        lines << "- severity: #{alert.severity}"
        lines << "- source: #{alert.source}"
        lines << "- revision: #{alert.revision}" if alert.revision && !alert.revision.to_s.empty?
        lines
      end

      def triage_context(triage_result)
        [
          "- confidence: #{(triage_result.confidence * 100).round}%",
          "- security_tier: #{triage_result.security_tier}",
          "- category: #{triage_result.category}"
        ]
      end
    end
  end
end
