# frozen_string_literal: true

require_relative 'agent_toolkit/version'
require_relative 'agent_toolkit/config'
require_relative 'agent_toolkit/structs'
require_relative 'agent_toolkit/fingerprint'
require_relative 'agent_toolkit/response_cleaner'
require_relative 'agent_toolkit/llm_client'
require_relative 'agent_toolkit/llm/base_provider'
require_relative 'agent_toolkit/llm/anthropic_provider'
require_relative 'agent_toolkit/llm/openai_provider'
require_relative 'agent_toolkit/issue_body_builder'
require_relative 'agent_toolkit/issue_manager'
require_relative 'agent_toolkit/agent_assigner'
require_relative 'agent_toolkit/pr_verifier'

module Telos
  # Shared infrastructure for Telos AI agent gems.
  module AgentToolkit
    class Error < StandardError; end

    class << self
      attr_writer :config

      def config
        @config ||= raise Error,
                          'Telos::AgentToolkit not configured. Call Telos::AgentToolkit.config = Config.load(path)'
      end
    end
  end
end
