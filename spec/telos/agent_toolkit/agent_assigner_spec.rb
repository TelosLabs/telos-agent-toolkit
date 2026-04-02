# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telos::AgentToolkit::AgentAssigner do
  let(:client) { instance_double(Octokit::Client) }

  let(:alert) do
    Telos::AgentToolkit::Alert.new(
      source: 'appsignal',
      error_class: 'NoMethodError',
      error_message: "undefined method `foo' for nil",
      severity: :error,
      occurrence_count: 42,
      revision: 'abc123',
      app_name: 'astro',
      incident_id: 'inc-001',
      raw_payload: {}
    )
  end

  let(:triage_result) do
    Telos::AgentToolkit::TriageResult.new(
      root_cause: 'Nil object access in UserController#show',
      confidence: 0.85,
      security_tier: :tier_one,
      fixable: true,
      affected_files: ['app/controllers/users_controller.rb'],
      suggested_fix: 'Add nil guard',
      data_related: false,
      category: :code_bug
    )
  end

  before do
    allow(Octokit::Client).to receive(:new).and_return(client)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('AGENT_ASSIGN_TOKEN').and_return('fake-token')
    allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return('fake-token')
  end

  def build_config(agent: 'claude')
    instance_double(
      Telos::AgentToolkit::Config,
      github_repo: 'TelosLabs/test-repo',
      raw: { 'auto_assign' => { 'agent' => agent, 'token_env' => 'AGENT_ASSIGN_TOKEN' } }
    )
  end

  describe '#assign' do
    it 'posts @claude comment with structured context' do
      allow(client).to receive(:add_comment)
      subject = described_class.new(build_config(agent: 'claude'))

      result = subject.assign(issue_number: 42, alert: alert, triage_result: triage_result)

      expect(result).to be true
      expect(client).to have_received(:add_comment) do |_repo, _number, comment|
        expect(comment).to start_with('@claude')
        expect(comment).to include('error_class: NoMethodError')
        expect(comment).to include('severity: error')
        expect(comment).to include('source: appsignal')
      end
    end

    it 'posts @copilot comment' do
      allow(client).to receive(:add_comment)
      subject = described_class.new(build_config(agent: 'copilot'))

      subject.assign(issue_number: 42, alert: alert, triage_result: triage_result)

      expect(client).to have_received(:add_comment) do |_repo, _number, comment|
        expect(comment).to start_with('@copilot')
      end
    end

    it 'posts @cursor comment' do
      allow(client).to receive(:add_comment)
      subject = described_class.new(build_config(agent: 'cursor'))

      subject.assign(issue_number: 42, alert: alert, triage_result: triage_result)

      expect(client).to have_received(:add_comment) do |_repo, _number, comment|
        expect(comment).to start_with('@cursor')
      end
    end

    it 'posts /opencode comment' do
      allow(client).to receive(:add_comment)
      subject = described_class.new(build_config(agent: 'opencode'))

      subject.assign(issue_number: 42, alert: alert, triage_result: triage_result)

      expect(client).to have_received(:add_comment) do |_repo, _number, comment|
        expect(comment).to start_with('/opencode')
      end
    end

    it 'includes Fixes #N reference' do
      allow(client).to receive(:add_comment)
      subject = described_class.new(build_config(agent: 'claude'))

      subject.assign(issue_number: 42, alert: alert, triage_result: triage_result)

      expect(client).to have_received(:add_comment) do |_repo, _number, comment|
        expect(comment).to include('Fixes #42')
      end
    end

    it 'includes affected files in context' do
      allow(client).to receive(:add_comment)
      subject = described_class.new(build_config(agent: 'claude'))

      subject.assign(issue_number: 42, alert: alert, triage_result: triage_result)

      expect(client).to have_received(:add_comment) do |_repo, _number, comment|
        expect(comment).to include('app/controllers/users_controller.rb')
      end
    end

    it 'returns false for unknown agent with warning' do
      subject = described_class.new(build_config(agent: 'unknown'))

      expect { subject.assign(issue_number: 42, alert: alert, triage_result: triage_result) }
        .to output(/Unknown agent 'unknown'/).to_stderr

      # Also verify it returns false
      allow($stderr).to receive(:write)
      result = subject.assign(issue_number: 42, alert: alert, triage_result: triage_result)
      expect(result).to be false
    end

    it 'handles Octokit::NotFound gracefully' do
      allow(client).to receive(:add_comment).and_raise(Octokit::NotFound)
      subject = described_class.new(build_config(agent: 'claude'))

      allow($stderr).to receive(:write)
      result = subject.assign(issue_number: 42, alert: alert, triage_result: triage_result)

      expect(result).to be false
    end

    it 'includes revision in context when present' do
      allow(client).to receive(:add_comment)
      subject = described_class.new(build_config(agent: 'claude'))

      subject.assign(issue_number: 42, alert: alert, triage_result: triage_result)

      expect(client).to have_received(:add_comment) do |_repo, _number, comment|
        expect(comment).to include('revision: abc123')
      end
    end
  end
end
