# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telos::AgentToolkit::Fingerprint do
  describe '.generate' do
    it 'produces consistent SHA1 for same inputs' do
      fp1 = described_class.generate(source: 'appsignal', error_class: 'NoMethodError', app_name: 'astro')
      fp2 = described_class.generate(source: 'appsignal', error_class: 'NoMethodError', app_name: 'astro')

      expect(fp1).to eq(fp2)
      expect(fp1).to match(/\A\h{40}\z/)
    end

    it 'produces different SHA1 for different inputs' do
      fp1 = described_class.generate(source: 'appsignal', error_class: 'NoMethodError', app_name: 'astro')
      fp2 = described_class.generate(source: 'rollbar', error_class: 'NoMethodError', app_name: 'astro')

      expect(fp1).not_to eq(fp2)
    end
  end

  describe '.to_html_comment' do
    it 'wraps fingerprint in an HTML comment with the prefix' do
      fingerprint = 'a' * 40
      comment = described_class.to_html_comment(fingerprint)

      expect(comment).to eq("<!-- toolkit:fingerprint:sha1:#{'a' * 40} -->")
    end
  end

  describe '.from_html_comment' do
    it 'extracts fingerprint from body containing the comment' do
      fingerprint = 'a' * 40
      body = "Some issue text\n<!-- toolkit:fingerprint:sha1:#{fingerprint} -->\nMore text"

      expect(described_class.from_html_comment(body)).to eq(fingerprint)
    end

    it 'returns nil for body without fingerprint' do
      expect(described_class.from_html_comment('No fingerprint here')).to be_nil
    end

    it 'returns nil for nil body' do
      expect(described_class.from_html_comment(nil)).to be_nil
    end
  end

  describe '.duplicate?' do
    let(:client) { instance_double('Octokit::Client') }
    let(:fingerprint) { 'a' * 40 }
    let(:repo) { 'TelosLabs/astro' }

    it 'returns the existing issue when a match is found' do
      issue = double('Issue', number: 42)
      search_result = double('SearchResult', total_count: 1, items: [issue])

      allow(client).to receive(:search_issues).and_return(search_result)

      result = described_class.duplicate?(client: client, repo: repo, fingerprint: fingerprint)

      expect(result).to eq(issue)
      expect(client).to have_received(:search_issues).with(
        "repo:#{repo} is:issue is:open in:body toolkit:fingerprint:sha1:#{fingerprint}",
        per_page: 1
      )
    end

    it 'returns nil when no match is found' do
      search_result = double('SearchResult', total_count: 0, items: [])

      allow(client).to receive(:search_issues).and_return(search_result)

      result = described_class.duplicate?(client: client, repo: repo, fingerprint: fingerprint)

      expect(result).to be_nil
    end
  end
end
