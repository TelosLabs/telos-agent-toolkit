# frozen_string_literal: true

require 'json'

module Telos
  module AgentToolkit
    # Multi-provider LLM client that dispatches to Anthropic or OpenAI.
    class LlmClient
      class Error < StandardError; end
      class TimeoutError < Error; end
      class RateLimitError < Error; end

      def initialize(config)
        @config = config
        @provider = build_provider
      end

      # Main entry point.
      # messages: array of {role:, content:} hashes
      # Returns: string response content
      def chat(messages:, model: nil, temperature: nil, max_tokens: nil)
        @provider.chat(
          messages: messages,
          model: model || @config.llm_model,
          temperature: temperature || @config.llm_temperature,
          max_tokens: max_tokens || @config.llm_max_tokens
        )
      end

      # Convenience: send system + user prompt, get string back.
      def triage(system_prompt:, user_prompt:)
        chat(messages: [
               { role: 'system', content: system_prompt },
               { role: 'user', content: user_prompt }
             ])
      end

      # Parse JSON from LLM response, with cleaning.
      def chat_json(messages:, model: nil, temperature: nil, max_tokens: nil)
        raw = chat(messages: messages, model: model, temperature: temperature, max_tokens: max_tokens)
        parse_json_response(raw)
      end

      private

      def build_provider
        case @config.llm_provider
        when 'anthropic'
          Llm::AnthropicProvider.new(@config)
        when 'openai'
          Llm::OpenaiProvider.new(@config)
        else
          raise Error, "Unknown LLM provider: #{@config.llm_provider}"
        end
      end

      def parse_json_response(raw)
        cleaned = ResponseCleaner.clean_json(raw)
        JSON.parse(cleaned)
      rescue JSON::ParserError
        raise Error, 'Failed to parse LLM JSON response'
      end
    end
  end
end
