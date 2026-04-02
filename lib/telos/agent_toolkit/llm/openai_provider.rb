# frozen_string_literal: true

require 'openai'

module Telos
  module AgentToolkit
    module Llm
      # LLM provider for OpenAI models via the ruby-openai gem.
      class OpenaiProvider < BaseProvider
        private

        def do_chat(messages:, model:, temperature:, max_tokens:)
          client = OpenAI::Client.new(access_token: api_key)
          params = build_params(messages, model, temperature, max_tokens)
          response = client.chat(parameters: params)
          extract_content(response)
        end

        def build_params(messages, model, temperature, max_tokens)
          params = {
            model: model,
            messages: messages.map { |m| { role: resolve(m, :role), content: resolve(m, :content) } }
          }

          assign_token_limit(params, model, max_tokens)
          params[:temperature] = temperature unless gpt5?(model)
          params
        end

        def assign_token_limit(params, model, max_tokens)
          if gpt5?(model)
            params[:max_completion_tokens] = max_tokens
          else
            params[:max_tokens] = max_tokens
          end
        end

        def gpt5?(model)
          model.to_s.downcase.start_with?('gpt-5')
        end

        def extract_content(response)
          message = response.dig('choices', 0, 'message', 'content')
          return message if message.is_a?(String)

          message.is_a?(Array) ? message.filter_map { |b| b['text'] }.join("\n") : message.to_s
        end

        def api_key
          ENV['OPENAI_API_KEY'] || @config.raw.dig('llm', 'openai_api_key')
        end

        def resolve(hash, key)
          hash[key] || hash[key.to_s]
        end
      end
    end
  end
end
