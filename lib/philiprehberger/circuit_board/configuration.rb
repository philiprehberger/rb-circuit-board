# frozen_string_literal: true

module Philiprehberger
  module CircuitBoard
    # DSL for defining health checks.
    class Configuration
      attr_reader :checks

      def initialize
        @checks = []
      end

      # Register a health check.
      #
      # @param name [Symbol] the check name
      # @param timeout [Numeric] timeout in seconds
      # @param block [Proc] block that returns truthy if healthy
      # @return [void]
      def check(name, timeout: 5, &block)
        @checks << Check.new(name, timeout: timeout, &block)
      end
    end
  end
end
