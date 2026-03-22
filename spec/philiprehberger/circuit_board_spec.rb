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
  end
end
