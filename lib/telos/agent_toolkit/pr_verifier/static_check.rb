# frozen_string_literal: true

module Telos
  module AgentToolkit
    class PrVerifier
      # Compares changed files against affected files from issue metadata.
      # Returns a conclusive result when overlap exists, otherwise defers to LLM.
      class StaticCheck
        def verify(changed_files:, affected_files:)
          return inconclusive('No affected files in metadata') if affected_files.empty?

          overlap = changed_files & affected_files
          extra_files = changed_files - affected_files

          return no_overlap_result if overlap.empty?

          build_pass_result(extra_files)
        end

        private

        def inconclusive(message)
          { conclusive: false, message: message }
        end

        def no_overlap_result
          inconclusive('Changed files don\'t overlap with affected files — deferring to LLM check.')
        end

        def build_pass_result(extra_files)
          message = if extra_files.empty?
                      'All changed files match affected files.'
                    else
                      'Changed files overlap with affected files, but additional files were modified.'
                    end

          { conclusive: true, status: :pass, message: message, scope_creep: extra_files }
        end
      end
    end
  end
end
