# frozen_string_literal: true

module Telos
  module AgentToolkit
    # Utilities for cleaning and extracting structured data from LLM responses.
    module ResponseCleaner
      module_function

      def clean_json(content)
        content = strip_markdown_fences(content.to_s.strip)
        extract_json_object(content)
      end

      def strip_markdown_fences(content)
        return content unless content.start_with?('```')

        content.gsub(/\A```(?:json)?\s*/, '').gsub(/\s*```\z/, '')
      end

      def extract_json_object(content)
        start_idx = content.index('{')
        end_idx = content.rindex('}')
        start_idx && end_idx && start_idx < end_idx ? content[start_idx..end_idx] : content
      end

      def fix_encoding_recursively(obj)
        case obj
        when Hash
          obj.transform_values { |v| fix_encoding_recursively(v) }
        when Array
          obj.map { |v| fix_encoding_recursively(v) }
        when String
          obj.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        else
          obj
        end
      end
    end
  end
end
