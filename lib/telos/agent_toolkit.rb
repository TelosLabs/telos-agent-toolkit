# frozen_string_literal: true

require_relative 'agent_toolkit/version'
require_relative 'agent_toolkit/config'

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
