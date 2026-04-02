# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telos::AgentToolkit::LlmClient do
  let(:config_hash) do
    {
      'llm' => {
        'provider' => provider,
        'model' => 'claude-sonnet-4-20250514',
        'max_tokens' => 4096,
        'temperature' => 0.2,
        'retry_attempts' => 3,
        'retry_base_delay_seconds' => 1.0
      },
      'github' => { 'repo' => 'TelosLabs/astro' }
    }
  end

  let(:provider) { 'anthropic' }
  let(:config) { Telos::AgentToolkit::Config.new(config_hash) }

  describe '#initialize' do
    it 'builds an Anthropic provider when configured' do
      client = described_class.new(config)

      expect(client.instance_variable_get(:@provider))
        .to be_a(Telos::AgentToolkit::Llm::AnthropicProvider)
    end

    context 'when provider is openai' do
      let(:provider) { 'openai' }

      it 'builds an OpenAI provider' do
        client = described_class.new(config)

        expect(client.instance_variable_get(:@provider))
          .to be_a(Telos::AgentToolkit::Llm::OpenaiProvider)
      end
    end

    context 'when provider is unknown' do
      let(:provider) { 'unknown' }

      it 'raises an error' do
        expect { described_class.new(config) }
          .to raise_error(described_class::Error, /Unknown LLM provider: unknown/)
      end
    end
  end

  describe '#chat' do
    let(:mock_provider) { instance_double(Telos::AgentToolkit::Llm::AnthropicProvider) }

    before do
      allow(Telos::AgentToolkit::Llm::AnthropicProvider).to receive(:new).and_return(mock_provider)
    end

    it 'delegates to the provider with config defaults' do
      client = described_class.new(config)
      messages = [{ role: 'user', content: 'Hello' }]

      allow(mock_provider).to receive(:chat).and_return('Hi there')

      result = client.chat(messages: messages)

      expect(result).to eq('Hi there')
      expect(mock_provider).to have_received(:chat).with(
        messages: messages,
        model: 'claude-sonnet-4-20250514',
        temperature: 0.2,
        max_tokens: 4096
      )
    end

    it 'allows overriding model, temperature, and max_tokens' do
      client = described_class.new(config)
      messages = [{ role: 'user', content: 'Hello' }]

      allow(mock_provider).to receive(:chat).and_return('response')

      client.chat(messages: messages, model: 'custom-model', temperature: 0.8, max_tokens: 1000)

      expect(mock_provider).to have_received(:chat).with(
        messages: messages,
        model: 'custom-model',
        temperature: 0.8,
        max_tokens: 1000
      )
    end
  end

  describe '#triage' do
    let(:mock_provider) { instance_double(Telos::AgentToolkit::Llm::AnthropicProvider) }

    before do
      allow(Telos::AgentToolkit::Llm::AnthropicProvider).to receive(:new).and_return(mock_provider)
      allow(mock_provider).to receive(:chat).and_return('triage result')
    end

    it 'sends system and user messages' do
      client = described_class.new(config)

      result = client.triage(system_prompt: 'You are a bot', user_prompt: 'What is this?')

      expect(result).to eq('triage result')
      expect(mock_provider).to have_received(:chat).with(
        messages: [
          { role: 'system', content: 'You are a bot' },
          { role: 'user', content: 'What is this?' }
        ],
        model: 'claude-sonnet-4-20250514',
        temperature: 0.2,
        max_tokens: 4096
      )
    end
  end

  describe '#chat_json' do
    let(:mock_provider) { instance_double(Telos::AgentToolkit::Llm::AnthropicProvider) }

    before do
      allow(Telos::AgentToolkit::Llm::AnthropicProvider).to receive(:new).and_return(mock_provider)
    end

    it 'parses valid JSON from the response' do
      allow(mock_provider).to receive(:chat).and_return('{"severity": "high", "count": 3}')

      client = described_class.new(config)
      result = client.chat_json(messages: [{ role: 'user', content: 'analyze' }])

      expect(result).to eq({ 'severity' => 'high', 'count' => 3 })
    end

    it 'handles markdown-fenced JSON' do
      allow(mock_provider).to receive(:chat).and_return("```json\n{\"key\": \"value\"}\n```")

      client = described_class.new(config)
      result = client.chat_json(messages: [{ role: 'user', content: 'analyze' }])

      expect(result).to eq({ 'key' => 'value' })
    end

    it 'raises an error on malformed JSON' do
      allow(mock_provider).to receive(:chat).and_return('not json at all')

      client = described_class.new(config)

      expect { client.chat_json(messages: [{ role: 'user', content: 'analyze' }]) }
        .to raise_error(described_class::Error, /Failed to parse LLM JSON response/)
    end
  end
end
