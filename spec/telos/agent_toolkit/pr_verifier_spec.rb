# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telos::AgentToolkit::PrVerifier do
  let(:config) do
    Telos::AgentToolkit::Config.new({
                                      'llm' => { 'provider' => 'anthropic', 'model' => 'claude-sonnet-4-5-20250514',
                                                 'max_tokens' => 4096 },
                                      'github' => { 'repo' => 'TelosLabs/test-repo', 'issue_prefix' => '[baymax]' }
                                    })
  end

  let(:client) { instance_double(Octokit::Client) }
  let(:pr_number) { 42 }

  let(:metadata_json) do
    {
      'affected_files' => ['app/models/user.rb', 'app/controllers/users_controller.rb'],
      'source' => 'appsignal',
      'error_class' => 'NoMethodError'
    }.to_json
  end

  let(:issue_body_with_metadata) do
    "Some issue description\n<!-- toolkit:metadata:#{metadata_json} -->"
  end

  let(:pr_body) { "Fix the user bug\n\nFixes #10" }
  let(:pr_object) { double('PR', body: pr_body) }
  let(:commit_message) { 'Fixes #10 — handle nil user' }
  let(:commit_object) { double('Commit', commit: double('CommitData', message: commit_message)) }

  let(:issue_object) { double('Issue', body: issue_body_with_metadata) }
  let(:pr_files) do
    [
      double('File', filename: 'app/models/user.rb'),
      double('File', filename: 'app/controllers/users_controller.rb')
    ]
  end

  before do
    allow(Octokit::Client).to receive(:new).and_return(client)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GITHUB_TOKEN').and_return('fake-token')
    allow(ENV).to receive(:fetch).with('GITHUB_REPOSITORY', anything).and_call_original
  end

  describe '#run' do
    subject(:verifier) { described_class.new(config, pr_number: pr_number) }

    before do
      allow(client).to receive(:pull_request).and_return(pr_object)
      allow(client).to receive(:pull_request_commits).and_return([commit_object])
      allow(client).to receive(:pull_request_files).and_return(pr_files)
      allow(client).to receive(:issue).and_return(issue_object)
      allow(client).to receive(:add_comment)
    end

    it 'extracts linked issues from PR body' do
      result = verifier.run

      expect(result[:status]).to eq(:completed)
      expect(result[:results].first[:issue]).to eq(10)
    end

    it 'extracts linked issues from commit messages' do
      allow(pr_object).to receive(:body).and_return('No refs here')
      commit_with_ref = double('Commit', commit: double('CommitData', message: 'Closes #55'))
      allow(client).to receive(:pull_request_commits).and_return([commit_with_ref])
      allow(client).to receive(:issue).with('TelosLabs/test-repo', 55).and_return(issue_object)

      result = verifier.run

      expect(result[:results].first[:issue]).to eq(55)
    end

    context 'when PR has no linked issues' do
      let(:pr_body) { 'Just some changes' }
      let(:commit_message) { 'Update stuff' }

      it 'posts a no-linked-issues comment and returns :no_linked_issues' do
        result = verifier.run

        expect(result[:status]).to eq(:no_linked_issues)
        expect(client).to have_received(:add_comment).with(
          'TelosLabs/test-repo', 42, a_string_including('No linked issues found')
        )
      end
    end

    context 'when static check passes with exact file match' do
      it 'returns :pass without calling LLM' do
        result = verifier.run

        issue_result = result[:results].first
        expect(issue_result[:status]).to eq(:pass)
        expect(issue_result[:message]).to include('All changed files match')
        expect(issue_result[:scope_creep]).to be_empty
      end
    end

    context 'when static check detects scope creep' do
      let(:pr_files) do
        [
          double('File', filename: 'app/models/user.rb'),
          double('File', filename: 'app/controllers/users_controller.rb'),
          double('File', filename: 'app/services/unrelated_service.rb')
        ]
      end

      it 'returns :pass with scope_creep files listed' do
        result = verifier.run

        issue_result = result[:results].first
        expect(issue_result[:status]).to eq(:pass)
        expect(issue_result[:scope_creep]).to eq(['app/services/unrelated_service.rb'])
      end
    end

    context 'when static check is inconclusive (no overlap)' do
      let(:pr_files) do
        [double('File', filename: 'app/services/totally_different.rb')]
      end

      let(:llm_client) { instance_double(Telos::AgentToolkit::LlmClient) }

      before do
        allow(Telos::AgentToolkit::LlmClient).to receive(:new).and_return(llm_client)
        allow(llm_client).to receive(:chat_json).and_return(
          'pass' => true,
          'reasoning' => 'The service change addresses the root cause.',
          'scope_creep' => []
        )
      end

      it 'falls back to LLM check' do
        result = verifier.run

        issue_result = result[:results].first
        expect(issue_result[:status]).to eq(:pass)
        expect(issue_result[:message]).to eq('The service change addresses the root cause.')
        expect(llm_client).to have_received(:chat_json)
      end
    end

    context 'when affected_files is empty in metadata' do
      let(:metadata_json) do
        { 'affected_files' => [], 'source' => 'appsignal' }.to_json
      end

      let(:llm_client) { instance_double(Telos::AgentToolkit::LlmClient) }

      before do
        allow(Telos::AgentToolkit::LlmClient).to receive(:new).and_return(llm_client)
        allow(llm_client).to receive(:chat_json).and_return(
          'pass' => false,
          'reasoning' => 'Cannot verify without affected files.',
          'scope_creep' => []
        )
      end

      it 'defers to LLM check' do
        result = verifier.run

        issue_result = result[:results].first
        expect(issue_result[:status]).to eq(:fail)
        expect(llm_client).to have_received(:chat_json)
      end
    end

    context 'when issue has no toolkit metadata' do
      let(:issue_object) { double('Issue', body: 'Just a plain issue with no metadata') }

      it 'returns :no_metadata' do
        result = verifier.run

        issue_result = result[:results].first
        expect(issue_result[:status]).to eq(:no_metadata)
        expect(issue_result[:message]).to eq('No toolkit metadata found')
      end
    end

    context 'with multiple linked issues' do
      let(:pr_body) { 'Fixes #10, Closes #20' }

      let(:first_issue) { double('Issue', body: issue_body_with_metadata) }
      let(:second_issue) { double('Issue', body: issue_body_with_metadata) }

      before do
        allow(client).to receive(:issue).with('TelosLabs/test-repo', 10).and_return(first_issue)
        allow(client).to receive(:issue).with('TelosLabs/test-repo', 20).and_return(second_issue)
      end

      it 'verifies each issue independently' do
        result = verifier.run

        expect(result[:results].length).to eq(2)
        expect(result[:results].map { |r| r[:issue] }).to contain_exactly(10, 20)
      end
    end

    context 'when dry_run is true' do
      subject(:verifier) { described_class.new(config, pr_number: pr_number, dry_run: true) }

      it 'skips posting comments' do
        verifier.run

        expect(client).not_to have_received(:add_comment)
      end
    end

    it 'posts a formatted verification comment' do
      verifier.run

      expect(client).to have_received(:add_comment).with(
        'TelosLabs/test-repo',
        42,
        a_string_including('Baymax Verification').and(a_string_including('PASS'))
      )
    end
  end
end
