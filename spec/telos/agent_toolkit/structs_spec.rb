# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telos::AgentToolkit do
  let(:alert_attrs) do
    {
      source: 'appsignal',
      error_class: 'NoMethodError',
      error_message: "undefined method 'foo' for nil",
      severity: :error,
      occurrence_count: 42,
      revision: 'abc123',
      app_name: 'astro',
      incident_id: 'inc_001',
      raw_payload: { key: 'value' }
    }
  end

  let(:triage_attrs) do
    {
      root_cause: 'Missing nil check in UserController#show',
      confidence: 0.85,
      security_tier: :tier_two,
      fixable: true,
      affected_files: ['app/controllers/users_controller.rb'],
      suggested_fix: 'Add a nil guard before accessing user.name',
      data_related: false,
      category: :code_bug
    }
  end

  let(:decision_attrs) do
    {
      action: :fix_with_review,
      reason: 'High confidence fix with security implications',
      urgent: true,
      labels: %w[bug auto-triage]
    }
  end

  let(:issue_metadata_attrs) do
    {
      fingerprint: 'a' * 40,
      alert: described_class::Alert.new(**alert_attrs),
      triage_result: described_class::TriageResult.new(**triage_attrs),
      decision: described_class::Decision.new(**decision_attrs),
      created_at: '2026-04-01T12:00:00Z'
    }
  end

  describe 'Alert' do
    it 'can be created with all fields' do
      alert = described_class::Alert.new(**alert_attrs)

      expect(alert.source).to eq('appsignal')
      expect(alert.error_class).to eq('NoMethodError')
      expect(alert.severity).to eq(:error)
      expect(alert.occurrence_count).to eq(42)
    end

    it 'is immutable' do
      alert = described_class::Alert.new(**alert_attrs)

      expect(alert).to be_frozen
    end

    it 'raises on missing required fields' do
      expect { described_class::Alert.new(source: 'appsignal') }.to raise_error(ArgumentError)
    end
  end

  describe 'TriageResult' do
    it 'can be created with all fields' do
      result = described_class::TriageResult.new(**triage_attrs)

      expect(result.root_cause).to eq('Missing nil check in UserController#show')
      expect(result.confidence).to eq(0.85)
      expect(result.security_tier).to eq(:tier_two)
      expect(result.fixable).to be(true)
      expect(result.category).to eq(:code_bug)
    end
  end

  describe 'Decision' do
    it 'can be created with all fields' do
      decision = described_class::Decision.new(**decision_attrs)

      expect(decision.action).to eq(:fix_with_review)
      expect(decision.reason).to eq('High confidence fix with security implications')
      expect(decision.urgent).to be(true)
      expect(decision.labels).to eq(%w[bug auto-triage])
    end
  end

  describe 'IssueMetadata' do
    it 'can be created with all fields' do
      metadata = described_class::IssueMetadata.new(**issue_metadata_attrs)

      expect(metadata.fingerprint).to eq('a' * 40)
      expect(metadata.alert).to be_a(described_class::Alert)
      expect(metadata.triage_result).to be_a(described_class::TriageResult)
      expect(metadata.decision).to be_a(described_class::Decision)
      expect(metadata.created_at).to eq('2026-04-01T12:00:00Z')
    end
  end
end
