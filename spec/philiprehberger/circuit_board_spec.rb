# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::CircuitBoard do
  before { Philiprehberger::CircuitBoard.reset! }

  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::CircuitBoard::VERSION).not_to be_nil
    end
  end

  describe '.configure' do
    it 'registers checks via DSL' do
      described_class.configure do
        check(:database) { true }
        check(:redis) { true }
      end

      status = described_class.check
      expect(status.results.length).to eq(2)
    end

    it 'replaces previous configuration' do
      described_class.configure do
        check(:old) { true }
      end
      described_class.configure do
        check(:new) { true }
      end

      status = described_class.check
      expect(status.results.length).to eq(1)
      expect(status.results.first[:name]).to eq(:new)
    end

    it 'accepts checks with custom timeouts' do
      described_class.configure do
        check(:db, timeout: 10) { true }
      end

      status = described_class.check
      expect(status.results.first[:healthy]).to be true
    end
  end

  describe '.check' do
    it 'returns a Status object' do
      described_class.configure do
        check(:test) { true }
      end

      expect(described_class.check).to be_a(Philiprehberger::CircuitBoard::Status)
    end

    it 'returns empty status with no checks configured' do
      status = described_class.check
      expect(status.results).to be_empty
      expect(status.healthy?).to be true
    end

    it 'runs all configured checks' do
      described_class.configure do
        check(:a) { true }
        check(:b) { true }
        check(:c) { true }
      end

      status = described_class.check
      expect(status.results.length).to eq(3)
    end
  end

  describe '.check_one' do
    it 'runs a single named check by symbol' do
      described_class.configure do
        check(:database) { true }
        check(:redis) { false }
      end

      result = described_class.check_one(:database)
      expect(result[:name]).to eq(:database)
      expect(result[:healthy]).to be true
    end

    it 'runs a single named check by string' do
      described_class.configure do
        check(:database) { true }
      end

      result = described_class.check_one('database')
      expect(result[:name]).to eq(:database)
      expect(result[:healthy]).to be true
    end

    it 'raises Error for unknown check name' do
      described_class.configure do
        check(:database) { true }
      end

      expect { described_class.check_one(:nonexistent) }
        .to raise_error(Philiprehberger::CircuitBoard::Error, 'unknown check: nonexistent')
    end

    it 'returns result hash with duration' do
      described_class.configure do
        check(:db) { true }
      end

      result = described_class.check_one(:db)
      expect(result).to have_key(:duration)
      expect(result[:duration]).to be_a(Float)
    end

    it 'captures exceptions as unhealthy' do
      described_class.configure do
        check(:broken) { raise 'connection failed' }
      end

      result = described_class.check_one(:broken)
      expect(result[:healthy]).to be false
      expect(result[:error]).to eq('connection failed')
    end

    it 'raises Error when no checks are configured' do
      expect { described_class.check_one(:anything) }
        .to raise_error(Philiprehberger::CircuitBoard::Error)
    end
  end

  describe '.reset!' do
    it 'clears all checks' do
      described_class.configure do
        check(:test) { true }
      end
      described_class.reset!
      status = described_class.check
      expect(status.results).to be_empty
    end
  end

  describe Philiprehberger::CircuitBoard::Status do
    describe '#healthy?' do
      it 'returns true when all checks pass' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { true }
          check(:b) { true }
        end

        expect(Philiprehberger::CircuitBoard.check.healthy?).to be true
      end

      it 'returns false when any check fails' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { true }
          check(:b) { false }
        end

        expect(Philiprehberger::CircuitBoard.check.healthy?).to be false
      end

      it 'returns false when all checks fail' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { false }
          check(:b) { false }
        end

        expect(Philiprehberger::CircuitBoard.check.healthy?).to be false
      end

      it 'returns true with no checks' do
        status = Philiprehberger::CircuitBoard::Status.new([])
        expect(status.healthy?).to be true
      end

      it 'returns true with single passing check' do
        Philiprehberger::CircuitBoard.configure do
          check(:only) { true }
        end

        expect(Philiprehberger::CircuitBoard.check.healthy?).to be true
      end

      it 'returns false with single failing check' do
        Philiprehberger::CircuitBoard.configure do
          check(:only) { false }
        end

        expect(Philiprehberger::CircuitBoard.check.healthy?).to be false
      end
    end

    describe '#degraded?' do
      it 'returns true when some checks pass and a non-critical one fails' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { true }
          check(:b, critical: false) { false }
        end

        expect(Philiprehberger::CircuitBoard.check.degraded?).to be true
      end

      it 'returns false when all checks pass' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { true }
        end

        expect(Philiprehberger::CircuitBoard.check.degraded?).to be false
      end

      it 'returns false when all checks fail' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { false }
          check(:b) { false }
        end

        expect(Philiprehberger::CircuitBoard.check.degraded?).to be false
      end

      it 'returns true with multiple passing and one non-critical failing' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { true }
          check(:b) { true }
          check(:c, critical: false) { false }
        end

        expect(Philiprehberger::CircuitBoard.check.degraded?).to be true
      end

      it 'returns false with no checks' do
        status = Philiprehberger::CircuitBoard::Status.new([])
        expect(status.degraded?).to be false
      end
    end

    describe '#to_h' do
      it 'returns hash with status and checks' do
        Philiprehberger::CircuitBoard.configure do
          check(:db) { true }
        end

        result = Philiprehberger::CircuitBoard.check.to_h
        expect(result[:status]).to eq('healthy')
        expect(result[:checks]).to be_an(Array)
        expect(result[:checks].first[:name]).to eq(:db)
        expect(result[:checks].first[:healthy]).to be true
      end

      it 'reports degraded status when non-critical check fails' do
        Philiprehberger::CircuitBoard.configure do
          check(:ok) { true }
          check(:bad, critical: false) { false }
        end

        result = Philiprehberger::CircuitBoard.check.to_h
        expect(result[:status]).to eq('degraded')
      end

      it 'reports unhealthy status' do
        Philiprehberger::CircuitBoard.configure do
          check(:bad) { false }
        end

        result = Philiprehberger::CircuitBoard.check.to_h
        expect(result[:status]).to eq('unhealthy')
      end

      it 'reports healthy status when all pass' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { true }
          check(:b) { true }
        end

        result = Philiprehberger::CircuitBoard.check.to_h
        expect(result[:status]).to eq('healthy')
      end

      it 'includes all check results' do
        Philiprehberger::CircuitBoard.configure do
          check(:db) { true }
          check(:redis) { true }
          check(:queue) { false }
        end

        result = Philiprehberger::CircuitBoard.check.to_h
        expect(result[:checks].length).to eq(3)
        names = result[:checks].map { |c| c[:name] }
        expect(names).to contain_exactly(:db, :redis, :queue)
      end

      it 'returns healthy for empty checks' do
        result = Philiprehberger::CircuitBoard.check.to_h
        expect(result[:status]).to eq('healthy')
        expect(result[:checks]).to be_empty
      end
    end

    describe '#results' do
      it 'returns the results array' do
        results = [{ name: :test, healthy: true, duration: 0.001 }]
        status = Philiprehberger::CircuitBoard::Status.new(results)
        expect(status.results).to eq(results)
      end
    end
  end

  describe Philiprehberger::CircuitBoard::Check do
    it 'captures exceptions as unhealthy' do
      check = described_class.new(:failing, timeout: 5) { raise 'boom' }
      result = check.call
      expect(result[:healthy]).to be false
      expect(result[:error]).to eq('boom')
    end

    it 'includes duration' do
      check = described_class.new(:fast, timeout: 5) { true }
      result = check.call
      expect(result[:duration]).to be_a(Float)
    end

    it 'returns healthy true for passing check' do
      check = described_class.new(:pass, timeout: 5) { true }
      result = check.call
      expect(result[:healthy]).to be true
    end

    it 'returns healthy false for failing check' do
      check = described_class.new(:fail, timeout: 5) { false }
      result = check.call
      expect(result[:healthy]).to be false
    end

    it 'includes the check name in results' do
      check = described_class.new(:my_check, timeout: 5) { true }
      result = check.call
      expect(result[:name]).to eq(:my_check)
    end

    it 'treats nil return as unhealthy' do
      check = described_class.new(:nil_check, timeout: 5) { nil }
      result = check.call
      expect(result[:healthy]).to be false
    end

    it 'treats truthy return as healthy' do
      check = described_class.new(:truthy, timeout: 5) { 'yes' }
      result = check.call
      expect(result[:healthy]).to be true
    end

    it 'has a name accessor' do
      check = described_class.new(:db, timeout: 5) { true }
      expect(check.name).to eq(:db)
    end

    it 'has a timeout accessor' do
      check = described_class.new(:db, timeout: 3) { true }
      expect(check.timeout).to eq(3)
    end

    it 'does not include error key for non-exception failures' do
      check = described_class.new(:fail, timeout: 5) { false }
      result = check.call
      expect(result).not_to have_key(:error)
    end

    it 'includes error key only for exceptions' do
      check = described_class.new(:err, timeout: 5) { raise 'oops' }
      result = check.call
      expect(result).to have_key(:error)
      expect(result[:error]).to eq('oops')
    end
  end

  describe Philiprehberger::CircuitBoard::Configuration do
    it 'starts with empty checks' do
      config = described_class.new
      expect(config.checks).to eq([])
    end

    it 'registers a check' do
      config = described_class.new
      config.check(:db) { true }
      expect(config.checks.length).to eq(1)
    end

    it 'registers multiple checks' do
      config = described_class.new
      config.check(:db) { true }
      config.check(:redis) { true }
      config.check(:queue) { true }
      expect(config.checks.length).to eq(3)
    end
  end

  describe 'on_change callback' do
    it 'calls callback when status changes' do
      transitions = []
      described_class.configure do |c|
        c.check('always_pass') { true }
        c.on_change { |from, to| transitions << [from, to] }
      end

      described_class.check
      described_class.check

      # Reconfigure to fail
      described_class.configure do |c|
        c.check('always_fail') { raise 'boom' }
        c.on_change { |from, to| transitions << [from, to] }
      end

      described_class.check
      expect(transitions.last).to eq(%i[healthy unhealthy])
    end

    it 'does not call callback on first check' do
      called = false
      described_class.configure do |c|
        c.check('pass') { true }
        c.on_change { |_from, _to| called = true }
      end

      described_class.check
      expect(called).to be false
    end

    it 'does not call callback when status unchanged' do
      call_count = 0
      described_class.configure do |c|
        c.check('pass') { true }
        c.on_change { |_from, _to| call_count += 1 }
      end

      3.times { described_class.check }
      expect(call_count).to eq(0)
    end
  end

  describe Philiprehberger::CircuitBoard::Rack::Middleware do
    let(:inner_app) { ->(_env) { [200, {}, ['ok']] } }
    let(:middleware) { described_class.new(inner_app) }

    before do
      Philiprehberger::CircuitBoard.configure do
        check(:test) { true }
      end
    end

    it 'responds to /health' do
      status, headers, body = middleware.call('PATH_INFO' => '/health')
      expect(status).to eq(200)
      expect(headers['content-type']).to eq('application/json')
      expect(body.first).to include('healthy')
    end

    it 'responds to /health/ready' do
      status, _headers, body = middleware.call('PATH_INFO' => '/health/ready')
      expect(status).to eq(200)
      expect(body.first).to include('ready')
    end

    it 'responds to /health/live' do
      status, _headers, body = middleware.call('PATH_INFO' => '/health/live')
      expect(status).to eq(200)
      expect(body.first).to include('alive')
    end

    it 'passes through non-health requests' do
      status, _headers, body = middleware.call('PATH_INFO' => '/other')
      expect(status).to eq(200)
      expect(body).to eq(['ok'])
    end

    it 'returns 503 when unhealthy' do
      Philiprehberger::CircuitBoard.configure do
        check(:bad) { false }
      end

      status, _headers, _body = middleware.call('PATH_INFO' => '/health')
      expect(status).to eq(503)
    end

    it 'returns 503 for /health/ready when unhealthy' do
      Philiprehberger::CircuitBoard.configure do
        check(:bad) { false }
      end

      status, _headers, body = middleware.call('PATH_INFO' => '/health/ready')
      expect(status).to eq(503)
      expect(body.first).to include('not_ready')
    end

    it 'returns JSON content type for /health/live' do
      _status, headers, _body = middleware.call('PATH_INFO' => '/health/live')
      expect(headers['content-type']).to eq('application/json')
    end

    it 'returns valid JSON from /health' do
      require 'json'
      _status, _headers, body = middleware.call('PATH_INFO' => '/health')
      parsed = JSON.parse(body.first)
      expect(parsed).to have_key('status')
      expect(parsed).to have_key('checks')
    end

    it 'returns valid JSON from /health/ready' do
      require 'json'
      _status, _headers, body = middleware.call('PATH_INFO' => '/health/ready')
      parsed = JSON.parse(body.first)
      expect(parsed).to have_key('status')
    end

    it 'returns valid JSON from /health/live' do
      require 'json'
      _status, _headers, body = middleware.call('PATH_INFO' => '/health/live')
      parsed = JSON.parse(body.first)
      expect(parsed['status']).to eq('alive')
    end
  end

  describe 'critical: option' do
    before { Philiprehberger::CircuitBoard.reset! }

    it 'defaults checks to critical' do
      described_class.configure do
        check(:db) { true }
      end
      result = described_class.check_one(:db)
      expect(result[:critical]).to be(true)
    end

    it 'allows marking a check as non-critical' do
      described_class.configure do
        check(:cache, critical: false) { true }
      end
      result = described_class.check_one(:cache)
      expect(result[:critical]).to be(false)
    end

    it 'returns degraded when only non-critical checks fail' do
      described_class.configure do
        check(:db) { true }
        check(:cache, critical: false) { false }
      end
      status = described_class.check
      expect(status.degraded?).to be(true)
      expect(status.to_h[:status]).to eq('degraded')
    end

    it 'returns unhealthy when a critical check fails' do
      described_class.configure do
        check(:db) { false }
        check(:cache, critical: false) { true }
      end
      status = described_class.check
      expect(status.healthy?).to be(false)
      expect(status.degraded?).to be(false)
      expect(status.to_h[:status]).to eq('unhealthy')
    end

    it 'returns healthy when all checks pass' do
      described_class.configure do
        check(:db) { true }
        check(:cache, critical: false) { true }
      end
      status = described_class.check
      expect(status.healthy?).to be(true)
      expect(status.to_h[:status]).to eq('healthy')
    end

    it 'returns unhealthy when all checks fail including critical' do
      described_class.configure do
        check(:db) { false }
        check(:cache, critical: false) { false }
      end
      status = described_class.check
      expect(status.to_h[:status]).to eq('unhealthy')
    end
  end

  describe '.check(parallel: true)' do
    it 'returns correct results when run in parallel' do
      described_class.configure do
        check(:a) { true }
        check(:b) { true }
        check(:c) { false }
      end
      status = described_class.check(parallel: true)
      expect(status.healthy?).to be false
      expect(status.results.length).to eq(3)
    end

    it 'collects all check names' do
      described_class.configure do
        check(:x) { true }
        check(:y) { true }
      end
      status = described_class.check(parallel: true)
      names = status.results.map { |r| r[:name] }
      expect(names).to contain_exactly(:x, :y)
    end
  end

  describe 'Status convenience methods' do
    it '#unhealthy_checks returns failed checks' do
      described_class.configure do
        check(:ok) { true }
        check(:fail) { false }
      end
      status = described_class.check
      expect(status.unhealthy_checks.length).to eq(1)
      expect(status.unhealthy_checks.first[:name]).to eq(:fail)
    end

    it '#healthy_checks returns passed checks' do
      described_class.configure do
        check(:ok) { true }
        check(:fail) { false }
      end
      status = described_class.check
      expect(status.healthy_checks.length).to eq(1)
      expect(status.healthy_checks.first[:name]).to eq(:ok)
    end

    it '#duration returns the max individual duration' do
      described_class.configure do
        check(:fast) { true }
      end
      status = described_class.check
      expect(status.duration).to be_a(Float)
      expect(status.duration).to be >= 0.0
    end

    it '#duration returns 0.0 when no checks' do
      status = Philiprehberger::CircuitBoard::Status.new([])
      expect(status.duration).to eq(0.0)
    end

    it '#to_json returns valid JSON' do
      described_class.configure do
        check(:db) { true }
      end
      status = described_class.check
      json = status.to_json
      parsed = JSON.parse(json)
      expect(parsed['status']).to eq('healthy')
      expect(parsed['checks']).to be_a(Array)
    end
  end
end
