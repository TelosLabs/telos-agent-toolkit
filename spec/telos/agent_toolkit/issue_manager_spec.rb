# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telos::AgentToolkit::IssueManager do
  let(:config) do
    instance_double(
      Telos::AgentToolkit::Config,
      github_repo: 'TelosLabs/test-repo',
      github_issue_prefix: '[baymax]'
    )
  end

  let(:client) { instance_double(Octokit::Client) }
  let(:fingerprint) { 'a' * 40 }

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
      suggested_fix: 'Add nil guard before accessing user attributes',
      data_related: false,
      category: :code_bug
    )
  end

  let(:decision) do
    Telos::AgentToolkit::Decision.new(
      action: :fix,
      reason: 'High confidence fix available',
      urgent: false,
      labels: []
    )
  end

  before do
    allow(Octokit::Client).to receive(:new).and_return(client)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GITHUB_TOKEN').and_return('fake-token')
  end

  describe '#ensure_labels!' do
    it 'creates all defined labels' do
      allow(client).to receive(:add_label)

      subject = described_class.new(config)
      subject.ensure_labels!

      described_class::LABEL_DEFINITIONS.each do |label|
        expect(client).to have_received(:add_label).with('TelosLabs/test-repo', label['name'], label['color'])
      end
    end

    it 'ignores UnprocessableEntity for existing labels' do
      allow(client).to receive(:add_label).and_raise(Octokit::UnprocessableEntity)

      subject = described_class.new(config)

      expect { subject.ensure_labels! }.not_to raise_error
    end
  end

  describe '#rate_limited?' do
    let(:subject) { described_class.new(config) }

    it 'returns false when max_per_hour is nil' do
      expect(subject.rate_limited?(nil)).to be false
    end

    it 'returns false when max_per_hour is zero' do
      expect(subject.rate_limited?(0)).to be false
    end

    it 'returns true when issue count meets the limit' do
      search_result = double('SearchResult', total_count: 5)
      allow(client).to receive(:search_issues).and_return(search_result)

      expect(subject.rate_limited?(5)).to be true
    end

    it 'returns false when issue count is below the limit' do
      search_result = double('SearchResult', total_count: 2)
      allow(client).to receive(:search_issues).and_return(search_result)

      expect(subject.rate_limited?(5)).to be false
    end
  end

  describe '#create_issue' do
    let(:subject) { described_class.new(config) }
    let(:created_issue) { double('Issue', number: 99) }

    before do
      allow(client).to receive(:add_label)
      allow(Telos::AgentToolkit::Fingerprint).to receive(:duplicate?).and_return(nil)
      allow(client).to receive(:create_issue).and_return(created_issue)
    end

    it 'creates an issue with the correct prefixed title' do
      result = subject.create_issue(alert: alert, triage_result: triage_result, decision: decision,
                                    fingerprint: fingerprint)

      expect(result).to eq({ status: :created, issue: created_issue })
      expect(client).to have_received(:create_issue).with(
        'TelosLabs/test-repo',
        "[baymax] NoMethodError: undefined method `foo' for nil",
        anything,
        anything
      )
    end

    it 'embeds fingerprint as HTML comment in body' do
      subject.create_issue(alert: alert, triage_result: triage_result, decision: decision, fingerprint: fingerprint)

      expect(client).to have_received(:create_issue) do |_repo, _title, body, _opts|
        expect(body).to include("<!-- toolkit:fingerprint:sha1:#{fingerprint} -->")
      end
    end

    it 'embeds machine-readable JSON metadata in HTML comments' do
      subject.create_issue(alert: alert, triage_result: triage_result, decision: decision, fingerprint: fingerprint)

      expect(client).to have_received(:create_issue) do |_repo, _title, body, _opts|
        expect(body).to match(/<!-- toolkit:metadata:\{.*"fingerprint".*\} -->/)
        metadata_match = body.match(/<!-- toolkit:metadata:(\{.*\}) -->/)
        metadata = JSON.parse(metadata_match[1])
        expect(metadata['source']).to eq('appsignal')
        expect(metadata['error_class']).to eq('NoMethodError')
        expect(metadata['decision_action']).to eq('fix')
        expect(metadata['confidence']).to eq(0.85)
      end
    end

    it 'skips creation when duplicate detected and adds comment' do
      existing_issue = double('Issue', number: 42)
      allow(Telos::AgentToolkit::Fingerprint).to receive(:duplicate?).and_return(existing_issue)
      allow(client).to receive(:add_comment)

      result = subject.create_issue(alert: alert, decision: decision, fingerprint: fingerprint)

      expect(result).to eq({ status: :duplicate, issue: existing_issue })
      expect(client).to have_received(:add_comment).with('TelosLabs/test-repo', 42, anything)
      expect(client).not_to have_received(:create_issue)
    end

    it 'builds correct severity labels' do
      subject.create_issue(alert: alert, triage_result: triage_result, decision: decision, fingerprint: fingerprint)

      expect(client).to have_received(:create_issue) do |_repo, _title, _body, opts|
        expect(opts[:labels]).to include('severity:error')
      end
    end

    it 'adds security tier labels when triage_result is present' do
      subject.create_issue(alert: alert, triage_result: triage_result, decision: decision, fingerprint: fingerprint)

      expect(client).to have_received(:create_issue) do |_repo, _title, _body, opts|
        expect(opts[:labels]).to include('security:tier-one')
      end
    end

    it 'adds baymax-fix label when decision is :fix' do
      subject.create_issue(alert: alert, triage_result: triage_result, decision: decision, fingerprint: fingerprint)

      expect(client).to have_received(:create_issue) do |_repo, _title, _body, opts|
        expect(opts[:labels]).to include('baymax-fix')
      end
    end

    it 'adds baymax-fix label when decision is :fix_with_review' do
      review_decision = Telos::AgentToolkit::Decision.new(
        action: :fix_with_review, reason: 'Needs review', urgent: false, labels: []
      )

      subject.create_issue(alert: alert, triage_result: triage_result, decision: review_decision,
                           fingerprint: fingerprint)

      expect(client).to have_received(:create_issue) do |_repo, _title, _body, opts|
        expect(opts[:labels]).to include('baymax-fix')
      end
    end

    it 'does not add baymax-fix label when decision is :skip' do
      skip_decision = Telos::AgentToolkit::Decision.new(
        action: :skip, reason: 'Not fixable', urgent: false, labels: []
      )

      subject.create_issue(alert: alert, triage_result: triage_result, decision: skip_decision,
                           fingerprint: fingerprint)

      expect(client).to have_received(:create_issue) do |_repo, _title, _body, opts|
        expect(opts[:labels]).not_to include('baymax-fix')
      end
    end

    it 'works without triage_result' do
      subject.create_issue(alert: alert, decision: decision, fingerprint: fingerprint)

      expect(client).to have_received(:create_issue) do |_repo, _title, body, opts|
        expect(body).not_to include('### Root Cause Analysis')
        expect(opts[:labels]).not_to include(a_string_matching(/security:/))
      end
    end
  end
end
