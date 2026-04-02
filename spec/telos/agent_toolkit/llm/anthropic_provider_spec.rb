# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telos::AgentToolkit::Llm::AnthropicProvider do
  let(:config_hash) do
    {
      'llm' => {
        'provider' => 'anthropic',
        'model' => 'claude-sonnet-4-20250514',
        'anthropic_api_key' => 'sk-config-key',
        'max_tokens' => 4096,
        'temperature' => 0.2,
        'retry_attempts' => 1,
        'retry_base_delay_seconds' => 0.01
      },
      'github' => { 'repo' => 'TelosLabs/astro' }
    }
  end

  let(:config) { Telos::AgentToolkit::Config.new(config_hash) }
  let(:provider) { described_class.new(config) }

  let(:mock_client) { instance_double(Anthropic::Client) }
  let(:mock_messages) { double('messages') }

  before do
    allow(Anthropic::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:messages).and_return(mock_messages)
  end

  describe '#chat' do
    let(:content_block) { double('content_block', text: 'Hello from Claude') }
    let(:response) { double('response', content: [content_block]) }

    it 'sends system as a separate param' do
      allow(mock_messages).to receive(:create).and_return(response)

      provider.chat(
        messages: [
          { role: 'system', content: 'You are a helper' },
          { role: 'user', content: 'Hi' }
        ],
        model: 'claude-sonnet-4-20250514',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(mock_messages).to have_received(:create).with(
        model: 'claude-sonnet-4-20250514',
        max_tokens: 4096,
        messages: [{ role: 'user', content: 'Hi' }],
        system: 'You are a helper',
        temperature: 0.2
      )
    end

    it 'omits system param when no system message' do
      allow(mock_messages).to receive(:create).and_return(response)

      provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'claude-sonnet-4-20250514',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(mock_messages).to have_received(:create).with(
        model: 'claude-sonnet-4-20250514',
        max_tokens: 4096,
        messages: [{ role: 'user', content: 'Hi' }],
        temperature: 0.2
      )
    end

    it 'extracts text content from the response' do
      allow(mock_messages).to receive(:create).and_return(response)

      result = provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'claude-sonnet-4-20250514',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(result).to eq('Hello from Claude')
    end

    it 'handles string-keyed message hashes' do
      allow(mock_messages).to receive(:create).and_return(response)

      provider.chat(
        messages: [
          { 'role' => 'system', 'content' => 'System prompt' },
          { 'role' => 'user', 'content' => 'User prompt' }
        ],
        model: 'claude-sonnet-4-20250514',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(mock_messages).to have_received(:create).with(
        model: 'claude-sonnet-4-20250514',
        max_tokens: 4096,
        messages: [{ role: 'user', content: 'User prompt' }],
        system: 'System prompt',
        temperature: 0.2
      )
    end
  end

  describe 'API key resolution' do
    after { ENV.delete('ANTHROPIC_API_KEY') }

    it 'uses ENV var when set' do
      ENV['ANTHROPIC_API_KEY'] = 'env-key'
      allow(mock_messages).to receive(:create).and_return(
        double('response', content: [double('block', text: 'ok')])
      )

      provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'claude-sonnet-4-20250514',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(Anthropic::Client).to have_received(:new).with(api_key: 'env-key')
    end

    it 'falls back to config key' do
      allow(mock_messages).to receive(:create).and_return(
        double('response', content: [double('block', text: 'ok')])
      )

      provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'claude-sonnet-4-20250514',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(Anthropic::Client).to have_received(:new).with(api_key: 'sk-config-key')
    end
  end

  describe 'retry on rate limit' do
    it 'retries on Anthropic rate limit errors' do
      call_count = 0
      content_block = double('content_block', text: 'ok')

      allow(mock_messages).to receive(:create) do
        call_count += 1
        if call_count == 1
          raise Anthropic::Errors::RateLimitError.new(
            url: 'https://api.anthropic.com/v1/messages',
            status: 429,
            headers: {},
            body: nil,
            request: {},
            response: {}
          )
        end

        double('response', content: [content_block])
      end

      allow(provider).to receive(:sleep)

      result = provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'claude-sonnet-4-20250514',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(result).to eq('ok')
    end
  end
end
