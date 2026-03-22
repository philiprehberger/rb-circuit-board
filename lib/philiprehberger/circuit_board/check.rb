# frozen_string_literal: true

module Philiprehberger
  module CircuitBoard
    # Represents a single health check definition.
    class Check
      attr_reader :name, :timeout

      # @param name [Symbol] the check name
      # @param timeout [Numeric] timeout in seconds
      # @param block [Proc] block that returns truthy if healthy
      def initialize(name, timeout: 5, &block)
        @name = name
        @timeout = timeout
        @block = block
      end

      # Execute the health check.
      #
      # @return [Hash] result with :name, :healthy, :duration, and optionally :error
      def call
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        healthy = execute_with_timeout
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        { name: @name, healthy: healthy, duration: duration.round(4) }
      rescue StandardError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        { name: @name, healthy: false, duration: duration.round(4), error: e.message }
      end

      private

      def execute_with_timeout
        result = nil
        thread = Thread.new { result = @block.call }
        unless thread.join(@timeout)
          thread.kill
          raise Error, "check #{@name} timed out after #{@timeout}s"
        end
        result ? true : false
      end
    end
  end
end
