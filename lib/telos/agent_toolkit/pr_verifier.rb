# frozen_string_literal: true

require 'json'
require 'octokit'
require_relative 'pr_verifier/comment_formatter'
require_relative 'pr_verifier/static_check'
require_relative 'pr_verifier/llm_check'

module Telos
  module AgentToolkit
    # Two-stage PR verifier: extracts linked issues, runs static + LLM checks,
    # and posts a verification comment on the PR.
    class PrVerifier
      class Error < StandardError; end

      ISSUE_REF = /\b(?:fix(?:es)?|close[sd]?|resolve[sd]?)\s*#(\d+)\b/i

      def initialize(config, pr_number:, dry_run: false)
        @config = config
        @pr_number = pr_number.to_i
        @dry_run = dry_run
        @repo = config.github_repo
        @client = Octokit::Client.new(access_token: ENV.fetch('GITHUB_TOKEN'))
      end

      def run
        issue_numbers = extract_issue_numbers

        return handle_no_linked_issues if issue_numbers.empty?

        changed_files = fetch_changed_files
        results = issue_numbers.map { |num| verify_issue(num, changed_files) }

        post_comment(CommentFormatter.format(results)) unless @dry_run
        { status: :completed, pr: @pr_number, results: results }
      end

      private

      def handle_no_linked_issues
        post_comment(CommentFormatter.no_linked_issues) unless @dry_run
        { status: :no_linked_issues, pr: @pr_number }
      end

      def extract_issue_numbers
        pr = @client.pull_request(@repo, @pr_number)
        body_refs = extract_refs(pr.body)

        commits = @client.pull_request_commits(@repo, @pr_number)
        commit_refs = commits.flat_map { |c| extract_refs(c.commit&.message) }

        (body_refs + commit_refs).uniq
      end

      def extract_refs(text)
        text.to_s.scan(ISSUE_REF).flatten.map(&:to_i)
      end

      def fetch_changed_files
        @client.pull_request_files(@repo, @pr_number).map(&:filename)
      end

      def verify_issue(issue_number, changed_files)
        issue = @client.issue(@repo, issue_number)
        metadata = extract_metadata(issue.body)

        return { issue: issue_number, status: :no_metadata, message: 'No toolkit metadata found' } unless metadata

        run_checks(issue_number, issue.body, changed_files, metadata)
      end

      def run_checks(issue_number, issue_body, changed_files, metadata)
        result = run_static_or_llm(issue_body, changed_files, metadata)
        result.merge(issue: issue_number)
      end

      def run_static_or_llm(issue_body, changed_files, metadata)
        static_result = run_static_check(changed_files, metadata)
        return static_result if static_result[:conclusive]

        run_llm_check(issue_body, changed_files)
      end

      def run_static_check(changed_files, metadata)
        StaticCheck.new.verify(
          changed_files: changed_files,
          affected_files: metadata['affected_files'] || []
        )
      end

      def run_llm_check(issue_body, changed_files)
        LlmCheck.new(@config).verify(
          issue_body: issue_body,
          changed_files: changed_files,
          pr_number: @pr_number,
          repo: @repo
        )
      end

      def extract_metadata(body)
        return nil if body.nil?

        match = body.match(/<!-- toolkit:metadata:(.+?) -->/)
        return nil unless match

        JSON.parse(match[1])
      rescue JSON::ParserError
        nil
      end

      def post_comment(body)
        @client.add_comment(@repo, @pr_number, body)
      end
    end
  end
end
