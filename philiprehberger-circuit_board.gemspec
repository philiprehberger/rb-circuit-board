# frozen_string_literal: true

require_relative 'lib/philiprehberger/circuit_board/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-circuit_board'
  spec.version = Philiprehberger::CircuitBoard::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'Health check framework with dependency aggregation and Rack endpoint'
  spec.description = 'Health check framework that aggregates dependency checks with configurable ' \
                     'timeouts. Provides a DSL for defining checks, aggregated status reporting, ' \
                     'and Rack middleware for /health, /health/ready, and /health/live endpoints.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-circuit_board'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-circuit-board'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-circuit-board/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-circuit-board/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
