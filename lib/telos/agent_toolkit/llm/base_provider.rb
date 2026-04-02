# frozen_string_literal: true

require 'faraday'

module Telos
  module AgentToolkit
    module Llm
      # Base class for LLM providers with retry logic and exponential backoff.
      class BaseProvider
        def initialize(config)
          @config = config
        end

        def chat(messages:, model:, temperature:, max_tokens:)
          with_retries do
            do_chat(messages: messages, model: model, temperature: temperature, max_tokens: max_tokens)
          end
        end

        private

        def do_chat(messages:, model:, temperature:, max_tokens:)
          raise NotImplementedError
        end

        def with_retries
          attempts = 0
          begin
            yield
          rescue *retryable_errors => e
            attempts += 1
            raise LlmClient::RateLimitError, e.message if attempts > retry_attempts

            sleep(retry_wait(e, attempts))
            retry
          end
        end

        def retryable_errors
          [Faraday::TooManyRequestsError, Faraday::ServerError]
        end

        def retry_attempts
          @config.llm_retry_attempts
        end

        def retry_wait(error, attempts)
          header_wait = extract_retry_after(error)
          base = header_wait || (@config.llm_retry_base_delay * (2**(attempts - 1)))
          base + (rand * 0.5)
        end

        def extract_retry_after(error)
          response = error.respond_to?(:response) ? error.response : nil
          return nil unless response.is_a?(Hash)

          headers = response[:headers]
          return nil unless headers

          value = headers['retry-after'] || headers['Retry-After']
          Float(value)
        rescue ArgumentError, TypeError
          nil
        end
      end
    end
  end
end
