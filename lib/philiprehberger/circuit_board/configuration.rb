# frozen_string_literal: true

module Philiprehberger
  module CircuitBoard
    # DSL for defining health checks.
    class Configuration
      attr_reader :checks

      def initialize
        @checks = []
        @on_change = nil
      end

      # Register a health check.
      #
      # @param name [Symbol] the check name
      # @param timeout [Numeric] timeout in seconds
      # @param block [Proc] block that returns truthy if healthy
      # @return [void]
      def check(name, timeout: 5, critical: true, &block)
        @checks << Check.new(name, timeout: timeout, critical: critical, &block)
      end

      # Register a callback for health status transitions.
      #
      # @yield [Symbol, Symbol] previous status and new status
      # @return [void]
      def on_change(&block)
        @on_change = block
      end

      # @return [Proc, nil] the on_change callback
      def on_change_callback
        @on_change
      end
    end
  end
end
