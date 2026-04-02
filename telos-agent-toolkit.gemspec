# frozen_string_literal: true

require_relative 'lib/telos/agent_toolkit/version'

Gem::Specification.new do |spec|
  spec.name = 'telos-agent-toolkit'
  spec.version = Telos::AgentToolkit::VERSION
  spec.authors = ['Telos Labs']
  spec.email = ['dev@teloslabs.co']

  spec.summary = 'Shared infrastructure for Telos AI agent gems'
  spec.description = 'Provides config loading, fingerprinting, LLM client, GitHub issue management, ' \
                     'agent assignment, and PR verification for the Telos AI agent ecosystem.'
  spec.homepage = 'https://github.com/TelosLabs/telos-agent-toolkit'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['exe/**/*', 'lib/**/*', 'LICENSE.txt', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'anthropic'
  spec.add_dependency 'faraday-retry'
  spec.add_dependency 'octokit', '~> 9.0'
  spec.add_dependency 'railties', '>= 7.0'
  spec.add_dependency 'ruby-openai', '~> 7.0'
end
