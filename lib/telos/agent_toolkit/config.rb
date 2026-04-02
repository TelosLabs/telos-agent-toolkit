# frozen_string_literal: true

require 'yaml'

module Telos
  module AgentToolkit
    # Loads and validates YAML configuration with typed accessors and ENV overrides.
    class Config
      REQUIRED_KEYS = %w[llm github].freeze

      ENV_OVERRIDES = {
        'anthropic_api_key' => 'ANTHROPIC_API_KEY',
        'openai_api_key' => 'OPENAI_API_KEY',
        'github_token' => 'GITHUB_TOKEN',
        'github_repo' => 'GITHUB_REPOSITORY'
      }.freeze

      attr_reader :raw

      def self.load(path)
        raise ArgumentError, "Config file not found: #{path}" unless File.exist?(path)

        raw = YAML.safe_load_file(path, aliases: true) || {}
        new(raw)
      end

      def initialize(raw)
        @raw = raw
        validate!
      end

      # --- LLM accessors ---

      def llm
        raw.fetch('llm')
      end

      def llm_provider
        llm.fetch('provider', 'anthropic')
      end

      def llm_model
        llm.fetch('model', 'claude-sonnet-4-20250514')
      end

      def llm_api_key
        env_key = "#{llm_provider.upcase}_API_KEY"
        ENV.fetch(env_key, llm.fetch('api_key', nil))
      end

      def llm_max_tokens
        llm.fetch('max_tokens', 4096)
      end

      def llm_temperature
        llm.fetch('temperature', 0.2)
      end

      def llm_retry_attempts
        llm.fetch('retry_attempts', 3)
      end

      def llm_retry_base_delay
        llm.fetch('retry_base_delay_seconds', 1.0)
      end

      # --- GitHub accessors ---

      def github
        raw.fetch('github')
      end

      def github_repo
        ENV.fetch('GITHUB_REPOSITORY', github.fetch('repo'))
      end

      def github_issue_prefix
        github.fetch('issue_prefix', '[Agent]')
      end

      def github_labels
        github.fetch('labels', [])
      end

      # --- Generic section access ---

      def section(name)
        raw.fetch(name.to_s)
      end

      private

      def validate!
        missing = REQUIRED_KEYS.reject { |key| raw.key?(key) }
        return if missing.empty?

        raise ArgumentError, "Missing required config keys: #{missing.join(', ')}"
      end
    end
  end
end
