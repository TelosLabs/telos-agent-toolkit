# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telos::AgentToolkit::ResponseCleaner do
  describe '.clean_json' do
    it 'strips markdown json fences' do
      input = "```json\n{\"key\": \"value\"}\n```"

      expect(described_class.clean_json(input)).to eq('{"key": "value"}')
    end

    it 'strips plain markdown fences' do
      input = "```\n{\"key\": \"value\"}\n```"

      expect(described_class.clean_json(input)).to eq('{"key": "value"}')
    end

    it 'extracts JSON object from surrounding text' do
      input = "Here is the result: {\"severity\": \"high\"} and that's it."

      expect(described_class.clean_json(input)).to eq('{"severity": "high"}')
    end

    it 'returns content as-is when no JSON braces found' do
      input = 'no json here'

      expect(described_class.clean_json(input)).to eq('no json here')
    end

    it 'handles whitespace around content' do
      input = "  \n  {\"a\": 1}  \n  "

      expect(described_class.clean_json(input)).to eq('{"a": 1}')
    end
  end

  describe '.strip_markdown_fences' do
    it 'removes json fences' do
      expect(described_class.strip_markdown_fences("```json\ncontent\n```")).to eq('content')
    end

    it 'removes plain fences' do
      expect(described_class.strip_markdown_fences("```\ncontent\n```")).to eq('content')
    end

    it 'leaves non-fenced content unchanged' do
      expect(described_class.strip_markdown_fences('just text')).to eq('just text')
    end
  end

  describe '.extract_json_object' do
    it 'extracts nested JSON' do
      input = 'prefix {"outer": {"inner": true}} suffix'

      expect(described_class.extract_json_object(input)).to eq('{"outer": {"inner": true}}')
    end

    it 'returns content when no opening brace' do
      expect(described_class.extract_json_object('no braces')).to eq('no braces')
    end

    it 'returns content when braces are inverted' do
      expect(described_class.extract_json_object('} before {')).to eq('} before {')
    end
  end

  describe '.fix_encoding_recursively' do
    it 'handles nested hashes' do
      input = { 'key' => 'value', 'nested' => { 'inner' => 'text' } }

      expect(described_class.fix_encoding_recursively(input)).to eq(input)
    end

    it 'handles arrays' do
      input = %w[one two three]

      expect(described_class.fix_encoding_recursively(input)).to eq(input)
    end

    it 'replaces invalid UTF-8 bytes in strings' do
      bad_string = "hello \xFF world".dup.force_encoding('UTF-8')

      result = described_class.fix_encoding_recursively(bad_string)

      expect(result).to be_valid_encoding
      expect(result).to include('hello')
      expect(result).to include('world')
    end

    it 'passes through non-string, non-collection values' do
      expect(described_class.fix_encoding_recursively(42)).to eq(42)
      expect(described_class.fix_encoding_recursively(nil)).to be_nil
    end

    it 'handles deeply nested structures' do
      input = { 'a' => [{ 'b' => 'text' }] }

      expect(described_class.fix_encoding_recursively(input)).to eq(input)
    end
  end
end
