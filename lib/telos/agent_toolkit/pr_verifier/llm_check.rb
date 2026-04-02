# frozen_string_literal: true

module Telos
  module AgentToolkit
    class PrVerifier
      # Falls back to LLM when static check is inconclusive.
      # Asks the LLM whether the PR addresses the linked issue.
      class LlmCheck
        def initialize(config)
          @llm = LlmClient.new(config)
        end

        def verify(issue_body:, changed_files:, pr_number:, repo:) # rubocop:disable Lint/UnusedMethodArgument
          response = @llm.chat_json(messages: [
                                      { role: 'system', content: system_prompt },
                                      { role: 'user', content: build_prompt(issue_body, changed_files, pr_number) }
                                    ])

          build_result(response)
        rescue LlmClient::Error, LlmClient::TimeoutError => e
          { conclusive: false, status: :inconclusive, message: "LLM verification failed: #{e.message}",
            scope_creep: [] }
        end

        private

        def system_prompt
          <<~PROMPT
            You are a PR verification assistant. You verify whether a PR's changes address
            the issue it claims to fix. Respond with JSON:
            {
              "pass": true/false,
              "reasoning": "explanation",
              "scope_creep": ["file1.rb", "file2.rb"]
            }
          PROMPT
        end

        def build_prompt(issue_body, changed_files, pr_number)
          <<~PROMPT
            ## Issue Body
            #{issue_body}

            ## Changed Files in PR ##{pr_number}
            #{changed_files.map { |f| "- #{f}" }.join("\n")}

            Does this PR address the issue? Are there unrelated file changes (scope creep)?
          PROMPT
        end

        def build_result(response)
          {
            conclusive: true,
            status: response['pass'] ? :pass : :fail,
            message: response['reasoning'] || 'LLM verification complete.',
            scope_creep: response['scope_creep'] || []
          }
        end
      end
    end
  end
end
