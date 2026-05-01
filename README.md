# philiprehberger-circuit_board

[![Tests](https://github.com/philiprehberger/rb-circuit-board/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-circuit-board/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-circuit_board.svg)](https://rubygems.org/gems/philiprehberger-circuit_board)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-circuit-board)](https://github.com/philiprehberger/rb-circuit-board/commits/main)

Health check framework with dependency aggregation and Rack endpoint

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-circuit_board"
```

Or install directly:

```bash
gem install philiprehberger-circuit_board
```

## Usage

```ruby
require "philiprehberger/circuit_board"

Philiprehberger::CircuitBoard.configure do
  check(:database) { ActiveRecord::Base.connection.active? }
  check(:redis, timeout: 2) { Redis.current.ping == 'PONG' }
end

status = Philiprehberger::CircuitBoard.check
status.healthy?   # => true
status.degraded?  # => false
status.to_h       # => { status: 'healthy', checks: [...] }
```

### Single Check

```ruby
result = Philiprehberger::CircuitBoard.check_one(:database)
# => { name: :database, healthy: true, duration: 0.0012 }
```

Raises `Philiprehberger::CircuitBoard::Error` if the named check does not exist.

### Rack Middleware

```ruby
# config.ru
require "philiprehberger/circuit_board"

Philiprehberger::CircuitBoard.configure do
  check(:database) { DB.connected? }
end

use Philiprehberger::CircuitBoard::Rack::Middleware
run MyApp
```

Exposes three endpoints:

- `GET /health` - full health check with all dependency results
- `GET /health/ready` - readiness probe (all checks must pass)
- `GET /health/live` - liveness probe (always returns 200)

### Critical and Non-Critical Checks

```ruby
Philiprehberger::CircuitBoard.configure do
  check(:database) { ActiveRecord::Base.connection.active? }          # critical (default)
  check(:cache, critical: false) { Redis.current.ping == 'PONG' }    # non-critical
end

status = Philiprehberger::CircuitBoard.check
# If only cache fails: status is "degraded"
# If database fails:   status is "unhealthy"
```

### Parallel Execution

Run all checks concurrently for lower latency:

```ruby
status = Philiprehberger::CircuitBoard.check(parallel: true)
status.healthy?          # => true
status.duration          # => wall-clock time of the slowest check
status.unhealthy_checks  # => []
status.to_json           # => '{"status":"healthy","checks":[...]}'
```

### Caching Expensive Checks

```ruby
Philiprehberger::CircuitBoard.configure do
  # Cache successful database probe for 30 seconds
  check(:database, cache: 30) { ActiveRecord::Base.connection.active? }
end

# First call hits the DB; subsequent calls within 30s return the cached result.
# Failed checks are never cached — failures re-run on every probe.
```

### Check Timeouts

```ruby
Philiprehberger::CircuitBoard.configure do
  check(:fast_service, timeout: 1) { FastService.ping }
  check(:slow_service, timeout: 10) { SlowService.ping }
end
```

### State Change Callback

```ruby
require "philiprehberger/circuit_board"

Philiprehberger::CircuitBoard.configure do |c|
  c.check("database") { ActiveRecord::Base.connection.active? }
  c.on_change do |from, to|
    puts "Health changed: #{from} -> #{to}"
  end
end
```

## API

| Method | Description |
|--------|-------------|
| `.configure { ... }` | Define health checks using the DSL (`check(name, timeout:, critical:, cache:)`) |
| `.check(parallel: false)` | Run all checks and return a Status; `parallel: true` runs concurrently |
| `.check_one(name)` | Run a single named check and return its result hash |
| `.reset!` | Remove all configured checks |
| `on_change(&block)` | Callback invoked on health status transitions |
| `Status#healthy?` | Whether all checks passed |
| `Status#degraded?` | Whether some checks passed but not all |
| `Status#to_h` | Hash with :status and :checks keys |
| `Status#results` | Array of individual check results |
| `Status#unhealthy_checks` | Failed check results |
| `Status#healthy_checks` | Passed check results |
| `Status#duration` | Wall-clock duration of slowest check |
| `Status#to_json` | JSON string of `to_h` |
| `Rack::Middleware.new(app)` | Rack middleware for health endpoints |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-circuit-board)

🐛 [Report issues](https://github.com/philiprehberger/rb-circuit-board/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-circuit-board/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
