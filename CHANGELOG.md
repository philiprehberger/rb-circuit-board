# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-04-04

### Added
- `on_change` callback for health status transitions
- GitHub issue template gem version field
- Feature request "Alternatives considered" field

## [0.1.7] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.1.6] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.1.5] - 2026-03-26

### Changed
- Add Sponsor badge to README
- Fix License section format


## [0.1.4] - 2026-03-24

### Fixed
- Fix stray character in CHANGELOG formatting

## [0.1.3] - 2026-03-22

### Changed
- Expanded test suite to 30+ examples covering edge cases, error paths, and boundary conditions

## [0.1.2] - 2026-03-22

### Changed
- Version bump for republishing
## [0.1.1] - 2026-03-22

### Changed
- Version bump for republishing

## [0.1.0] - 2026-03-22

### Added
- Initial release
- DSL for defining health checks with configurable timeouts
- Aggregated status reporting with healthy, degraded, and unhealthy states
- Rack middleware for /health, /health/ready, and /health/live endpoints
- Thread-based timeout for individual checks
