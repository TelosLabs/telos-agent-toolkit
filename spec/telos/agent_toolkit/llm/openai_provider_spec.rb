# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telos::AgentToolkit::Llm::OpenaiProvider do
  let(:config_hash) do
    {
      'llm' => {
        'provider' => 'openai',
        'model' => 'gpt-4o',
        'openai_api_key' => 'sk-openai-key',
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
  let(:mock_client) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(mock_client)
  end

  describe '#chat' do
    let(:response) do
      { 'choices' => [{ 'message' => { 'content' => 'Hello from GPT' } }] }
    end

    it 'sends correct request format' do
      allow(mock_client).to receive(:chat).and_return(response)

      result = provider.chat(
        messages: [
          { role: 'system', content: 'You are helpful' },
          { role: 'user', content: 'Hi' }
        ],
        model: 'gpt-4o',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(result).to eq('Hello from GPT')
      expect(mock_client).to have_received(:chat).with(
        parameters: {
          model: 'gpt-4o',
          messages: [
            { role: 'system', content: 'You are helpful' },
            { role: 'user', content: 'Hi' }
          ],
          max_tokens: 4096,
          temperature: 0.2
        }
      )
    end

    it 'uses max_completion_tokens for GPT-5 models' do
      allow(mock_client).to receive(:chat).and_return(response)

      provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'gpt-5',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(mock_client).to have_received(:chat).with(
        parameters: hash_including(max_completion_tokens: 4096)
      )
    end

    it 'uses max_tokens for non-GPT-5 models' do
      allow(mock_client).to receive(:chat).and_return(response)

      provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'gpt-4o',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(mock_client).to have_received(:chat).with(
        parameters: hash_including(max_tokens: 4096)
      )
    end

    it 'omits temperature for GPT-5 models' do
      allow(mock_client).to receive(:chat).and_return(response)

      provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'gpt-5-turbo',
        temperature: 0.5,
        max_tokens: 4096
      )

      expect(mock_client).to have_received(:chat).with(
        parameters: hash_not_including(:temperature)
      )
    end

    it 'includes temperature for non-GPT-5 models' do
      allow(mock_client).to receive(:chat).and_return(response)

      provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'gpt-4o',
        temperature: 0.7,
        max_tokens: 4096
      )

      expect(mock_client).to have_received(:chat).with(
        parameters: hash_including(temperature: 0.7)
      )
    end

    it 'extracts content from response' do
      allow(mock_client).to receive(:chat).and_return(response)

      result = provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'gpt-4o',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(result).to eq('Hello from GPT')
    end

    it 'handles string-keyed message hashes' do
      allow(mock_client).to receive(:chat).and_return(response)

      provider.chat(
        messages: [{ 'role' => 'user', 'content' => 'Hi' }],
        model: 'gpt-4o',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(mock_client).to have_received(:chat).with(
        parameters: hash_including(
          messages: [{ role: 'user', content: 'Hi' }]
        )
      )
    end
  end

  describe 'API key resolution' do
    after { ENV.delete('OPENAI_API_KEY') }

    it 'uses ENV var when set' do
      ENV['OPENAI_API_KEY'] = 'env-openai-key'
      allow(mock_client).to receive(:chat).and_return(
        { 'choices' => [{ 'message' => { 'content' => 'ok' } }] }
      )

      provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'gpt-4o',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(OpenAI::Client).to have_received(:new).with(access_token: 'env-openai-key')
    end

    it 'falls back to config key' do
      allow(mock_client).to receive(:chat).and_return(
        { 'choices' => [{ 'message' => { 'content' => 'ok' } }] }
      )

      provider.chat(
        messages: [{ role: 'user', content: 'Hi' }],
        model: 'gpt-4o',
        temperature: 0.2,
        max_tokens: 4096
      )

      expect(OpenAI::Client).to have_received(:new).with(access_token: 'sk-openai-key')
    end
  end

  # Custom matcher for hash_not_including
  RSpec::Matchers.define :hash_not_including do |*keys|
    match do |actual|
      keys.none? { |key| actual.key?(key) }
    end
  end
end
