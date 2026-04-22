# frozen_string_literal: true

module Philiprehberger
  module CircuitBoard
    # Represents the aggregated health status of all checks.
    class Status
      attr_reader :results

      # @param results [Array<Hash>] individual check results
      def initialize(results)
        @results = results
      end

      # Whether all checks passed.
      #
      # @return [Boolean]
      def healthy?
        @results.all? { |r| r[:healthy] }
      end

      # Return check results that failed.
      #
      # @return [Array<Hash>]
      def unhealthy_checks
        @results.reject { |r| r[:healthy] }
      end

      # Return check results that passed.
      #
      # @return [Array<Hash>]
      def healthy_checks
        @results.select { |r| r[:healthy] }
      end

      # Total wall-clock duration (max of individual durations).
      #
      # @return [Float]
      def duration
        return 0.0 if @results.empty?

        @results.map { |r| r[:duration] || 0.0 }.max
      end

      # JSON representation.
      #
      # @return [String]
      def to_json(*_args)
        require 'json'
        JSON.generate(to_h)
      end

      # Whether the system is degraded: all critical checks pass but at least one non-critical fails.
      #
      # @return [Boolean]
      def degraded?
        return false if healthy?

        critical_ok? && @results.any? { |r| !r[:healthy] }
      end

      # Convert to a hash representation.
      #
      # @return [Hash] status hash with :status and :checks keys
      def to_h
        {
          status: compute_status,
          checks: @results
        }
      end

      private

      def critical_ok?
        @results.select { |r| r[:critical] }.all? { |r| r[:healthy] }
      end

      def compute_status
        return 'healthy' if healthy?
        return 'degraded' if degraded?

        'unhealthy'
      end
    end
  end
end
