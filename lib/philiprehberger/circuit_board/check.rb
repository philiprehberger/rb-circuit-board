# frozen_string_literal: true

module Philiprehberger
  module CircuitBoard
    # Represents a single health check definition.
    class Check
      attr_reader :name, :timeout, :critical, :cache

      # @param name [Symbol] the check name
      # @param timeout [Numeric] timeout in seconds
      # @param critical [Boolean] whether this check is critical (default: true)
      # @param cache [Numeric, nil] cache successful results for this many seconds (default: nil — no caching)
      # @param block [Proc] block that returns truthy if healthy
      def initialize(name, timeout: 5, critical: true, cache: nil, &block)
        @name = name
        @timeout = timeout
        @critical = critical
        @cache = cache
        @block = block
        @cache_mutex = Mutex.new
        @cached_result = nil
        @cached_at = nil
      end

      # Execute the health check, returning a cached result if available.
      #
      # @return [Hash] result with :name, :healthy, :duration, and optionally :error
      def call
        cached = read_cache
        return cached if cached

        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        healthy = execute_with_timeout
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        result = { name: @name, healthy: healthy, critical: @critical, duration: duration.round(4) }
        write_cache(result) if healthy
        result
      rescue StandardError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        { name: @name, healthy: false, critical: @critical, duration: duration.round(4), error: e.message }
      end

      private

      def read_cache
        return nil unless @cache

        @cache_mutex.synchronize do
          return nil unless @cached_at && (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @cached_at) < @cache

          @cached_result
        end
      end

      def write_cache(result)
        @cache_mutex.synchronize do
          @cached_result = result
          @cached_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

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
