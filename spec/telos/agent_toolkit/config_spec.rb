# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Telos::AgentToolkit::Config do
  let(:valid_config) do
    {
      'llm' => {
        'provider' => 'anthropic',
        'model' => 'claude-sonnet-4-20250514',
        'api_key' => 'sk-test-key',
        'max_tokens' => 8192,
        'temperature' => 0.3,
        'retry_attempts' => 5,
        'retry_base_delay_seconds' => 2.0
      },
      'github' => {
        'repo' => 'TelosLabs/astro',
        'issue_prefix' => '[Baymax]',
        'labels' => %w[agent bug]
      }
    }
  end

  let(:config_path) do
    file = Tempfile.new(['agent_config', '.yml'])
    file.write(YAML.dump(valid_config))
    file.close
    file.path
  end

  after do
    ENV.delete('ANTHROPIC_API_KEY')
    ENV.delete('GITHUB_REPOSITORY')
  end

  describe '.load' do
    it 'loads a valid YAML config file' do
      config = described_class.load(config_path)

      expect(config.raw).to eq(valid_config)
    end

    it 'raises ArgumentError for a missing file' do
      expect { described_class.load('/nonexistent/config.yml') }
        .to raise_error(ArgumentError, /Config file not found/)
    end
  end

  describe 'validation' do
    it 'raises ArgumentError listing missing required keys' do
      expect { described_class.new({}) }
        .to raise_error(ArgumentError, /Missing required config keys: llm, github/)
    end

    it 'raises when only some keys are present' do
      expect { described_class.new('llm' => {}) }
        .to raise_error(ArgumentError, /Missing required config keys: github/)
    end
  end

  describe 'LLM accessors' do
    subject(:config) { described_class.new(valid_config) }

    it 'returns the provider' do
      expect(config.llm_provider).to eq('anthropic')
    end

    it 'returns the model' do
      expect(config.llm_model).to eq('claude-sonnet-4-20250514')
    end

    it 'returns max_tokens' do
      expect(config.llm_max_tokens).to eq(8192)
    end

    it 'returns temperature' do
      expect(config.llm_temperature).to eq(0.3)
    end

    it 'returns retry_attempts' do
      expect(config.llm_retry_attempts).to eq(5)
    end

    it 'returns retry_base_delay' do
      expect(config.llm_retry_base_delay).to eq(2.0)
    end

    it 'returns the api_key from config' do
      expect(config.llm_api_key).to eq('sk-test-key')
    end

    it 'defaults provider to anthropic' do
      minimal = described_class.new('llm' => {}, 'github' => { 'repo' => 'x' })

      expect(minimal.llm_provider).to eq('anthropic')
    end
  end

  describe 'GitHub accessors' do
    subject(:config) { described_class.new(valid_config) }

    it 'returns the repo' do
      expect(config.github_repo).to eq('TelosLabs/astro')
    end

    it 'returns the issue prefix' do
      expect(config.github_issue_prefix).to eq('[Baymax]')
    end

    it 'returns labels' do
      expect(config.github_labels).to eq(%w[agent bug])
    end
  end

  describe 'ENV var overrides' do
    subject(:config) { described_class.new(valid_config) }

    it 'overrides llm_api_key with ANTHROPIC_API_KEY env var' do
      ENV['ANTHROPIC_API_KEY'] = 'env-override-key'

      expect(config.llm_api_key).to eq('env-override-key')
    end

    it 'overrides github_repo with GITHUB_REPOSITORY env var' do
      ENV['GITHUB_REPOSITORY'] = 'TelosLabs/other-repo'

      expect(config.github_repo).to eq('TelosLabs/other-repo')
    end
  end

  describe '#section' do
    it 'returns a named section from raw config' do
      config = described_class.new(valid_config)

      expect(config.section(:llm)).to eq(valid_config['llm'])
    end

    it 'raises KeyError for unknown sections' do
      config = described_class.new(valid_config)

      expect { config.section(:unknown) }.to raise_error(KeyError)
    end
  end
end
