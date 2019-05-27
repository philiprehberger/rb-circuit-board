# frozen_string_literal: true

require_relative 'circuit_board/version'
require_relative 'circuit_board/check'
require_relative 'circuit_board/status'
require_relative 'circuit_board/configuration'
require_relative 'circuit_board/middleware'

module Philiprehberger
  module CircuitBoard
    class Error < StandardError; end

    @configuration = Configuration.new

    # Configure health checks using a DSL block.
    #
    # @yield [Configuration] the configuration instance
    # @return [void]
    def self.configure(&)
      @configuration = Configuration.new
      @configuration.instance_eval(&)
    end

    # Run all configured health checks and return an aggregated status.
    #
    # @return [Status] the aggregated health status
    def self.check
      results = @configuration.checks.map(&:call)
      Status.new(results)
    end

    # Reset all configured checks.
    #
    # @return [void]
    def self.reset!
      @configuration = Configuration.new
    end
  end
end
