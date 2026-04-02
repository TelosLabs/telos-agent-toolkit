# frozen_string_literal: true

module Telos
  module AgentToolkit
    # Normalized alert from any observability tool
    Alert = Data.define(
      :source,           # "appsignal", "rollbar"
      :error_class,      # e.g., "NoMethodError"
      :error_message,    # truncated to 500 chars
      :severity,         # :info, :warning, :error, :critical
      :occurrence_count, # integer
      :revision,         # git SHA
      :app_name,         # project name
      :incident_id,      # observability tool's ID
      :raw_payload       # original payload hash for adapter-specific access
    )

    # Result of LLM triage
    TriageResult = Data.define(
      :root_cause,       # string description
      :confidence,       # float 0.0-1.0
      :security_tier,    # :tier_one, :tier_two, :tier_three
      :fixable,          # boolean
      :affected_files,   # array of file paths
      :suggested_fix,    # string description
      :data_related,     # boolean - involves data/migrations
      :category          # :code_bug, :config, :dependency, :infra, :data
    )

    # Decision from decision engine
    Decision = Data.define(
      :action,           # :skip, :diagnosis_only, :fix, :fix_with_review, :queued
      :reason,           # human-readable explanation
      :urgent,           # boolean
      :labels            # array of GitHub label strings
    )

    # GitHub issue metadata embedded as HTML comment
    IssueMetadata = Data.define(
      :fingerprint,      # SHA1 hex string
      :alert,            # Alert struct (serialized)
      :triage_result,    # TriageResult struct (serialized, optional)
      :decision,         # Decision struct (serialized)
      :created_at        # ISO8601 timestamp
    )
  end
end
