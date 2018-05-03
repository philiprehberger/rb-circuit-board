# philiprehberger-circuit_board

[![Tests](https://github.com/philiprehberger/rb-circuit-board/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-circuit-board/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-circuit_board.svg)](https://rubygems.org/gems/philiprehberger-circuit_board)
[![License](https://img.shields.io/github/license/philiprehberger/rb-circuit-board)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

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

### Check Timeouts

```ruby
Philiprehberger::CircuitBoard.configure do
  check(:fast_service, timeout: 1) { FastService.ping }
  check(:slow_service, timeout: 10) { SlowService.ping }
end
```

## API

| Method | Description |
|--------|-------------|
| `.configure { ... }` | Define health checks using the DSL |
| `.check` | Run all checks and return a Status |
| `.reset!` | Remove all configured checks |
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

## License

[MIT](LICENSE)
