# frozen_string_literal: true

module Philiprehberger
  module CircuitBoard
    module Rack
      # Rack middleware that exposes /health, /health/ready, and /health/live endpoints.
      class Middleware
        HEALTH_PATHS = %w[/health /health/ready /health/live].freeze

        # @param app [#call] the Rack application
        def initialize(app)
          @app = app
        end

        # @param env [Hash] Rack environment
        # @return [Array] Rack response
        def call(env)
          path = env['PATH_INFO']

          case path
          when '/health'
            health_response
          when '/health/ready'
            ready_response
          when '/health/live'
            live_response
          else
            @app.call(env)
          end
        end

        private

        def health_response
          status = CircuitBoard.check
          code = status.healthy? ? 200 : 503
          body = json_encode(status.to_h)
          [code, { 'content-type' => 'application/json' }, [body]]
        end

        def ready_response
          status = CircuitBoard.check
          code = status.healthy? ? 200 : 503
          body = json_encode({ status: status.healthy? ? 'ready' : 'not_ready', checks: status.results })
          [code, { 'content-type' => 'application/json' }, [body]]
        end

        def live_response
          [200, { 'content-type' => 'application/json' }, [json_encode({ status: 'alive' })]]
        end

        def json_encode(obj)
          require 'json'
          JSON.generate(obj)
        end
      end
    end
  end
end
