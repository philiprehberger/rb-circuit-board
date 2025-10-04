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
| `.configure { ... }` | Define health checks using the DSL (`check(name, timeout:, critical:)`) |
| `.check` | Run all checks and return a Status |
| `.check_one(name)` | Run a single named check and return its result hash |
| `.reset!` | Remove all configured checks |
| `on_change(&block)` | Callback invoked on health status transitions |
| `Status#healthy?` | Whether all checks passed |
| `Status#degraded?` | Whether some checks passed but not all |
| `Status#to_h` | Hash with :status and :checks keys |
| `Status#results` | Array of individual check results |
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
