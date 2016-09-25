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
      it 'returns true when some checks pass and some fail' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { true }
          check(:b) { false }
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

      it 'returns true with multiple passing and one failing' do
        Philiprehberger::CircuitBoard.configure do
          check(:a) { true }
          check(:b) { true }
          check(:c) { false }
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

      it 'reports degraded status' do
        Philiprehberger::CircuitBoard.configure do
          check(:ok) { true }
          check(:bad) { false }
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
end
