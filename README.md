# Telos Agent Toolkit

Shared infrastructure gem for the Telos Labs AI agent ecosystem. Provides config loading, fingerprinting, LLM client wrappers, GitHub issue management, agent assignment, and PR verification used by agents like Baymax (production alerts), Wall-E (tech debt), and Eva (auto-fixes).

## Installation

Add to your Gemfile:

```ruby
gem "telos-agent-toolkit", github: "TelosLabs/telos-agent-toolkit"
```

## Usage

### Configuration

Create a YAML config file (e.g., `.agent.yml`):

```yaml
llm:
  provider: anthropic
  model: claude-sonnet-4-20250514
  max_tokens: 4096
  temperature: 0.2

github:
  repo: TelosLabs/your-repo
  issue_prefix: "[Agent]"
  labels:
    - agent
    - automated
```

Load it in your agent:

```ruby
require "telos/agent_toolkit"

Telos::AgentToolkit.config = Telos::AgentToolkit::Config.load(".agent.yml")

# Access values via typed methods
Telos::AgentToolkit.config.llm_provider    # => "anthropic"
Telos::AgentToolkit.config.github_repo     # => "TelosLabs/your-repo"
Telos::AgentToolkit.config.llm_max_tokens  # => 4096
```

API keys are resolved from environment variables automatically (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GITHUB_TOKEN`, `GITHUB_REPOSITORY`).

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
