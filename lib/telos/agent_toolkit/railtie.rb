# frozen_string_literal: true

require 'rails/railtie'

module Telos
  module AgentToolkit
    # Integrates the toolkit with Rails applications.
    class Railtie < Rails::Railtie
      railtie_name :telos_agent_toolkit
    end
  end
end
