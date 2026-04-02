# frozen_string_literal: true

require 'anthropic'

module Telos
  module AgentToolkit
    module Llm
      # LLM provider for Anthropic's Claude models via the anthropic gem.
      class AnthropicProvider < BaseProvider
        private

        def do_chat(messages:, model:, temperature:, max_tokens:)
          client = Anthropic::Client.new(api_key: api_key)

          system_msg, user_msgs = partition_messages(messages)

          params = build_params(model, max_tokens, user_msgs, system_msg, temperature)
          response = client.messages.create(**params)
          extract_content(response)
        end

        def partition_messages(messages)
          system_msg = messages.find { |m| resolve(m, :role) == 'system' }
          user_msgs = messages.reject { |m| resolve(m, :role) == 'system' }
          [system_msg, user_msgs]
        end

        def build_params(model, max_tokens, user_msgs, system_msg, temperature)
          params = {
            model: model,
            max_tokens: max_tokens,
            messages: user_msgs.map { |m| { role: resolve(m, :role), content: resolve(m, :content) } }
          }
          params[:system] = resolve(system_msg, :content) if system_msg
          params[:temperature] = temperature if temperature
          params
        end

        def extract_content(response)
          content = response.content
          return content.first.text if content.is_a?(Array) && content.first.respond_to?(:text)

          content.to_s
        end

        def retryable_errors
          super + [Anthropic::Errors::RateLimitError, Anthropic::Errors::InternalServerError]
        end

        def api_key
          ENV['ANTHROPIC_API_KEY'] || @config.raw.dig('llm', 'anthropic_api_key')
        end

        def resolve(hash, key)
          hash[key] || hash[key.to_s]
        end
      end
    end
  end
end
