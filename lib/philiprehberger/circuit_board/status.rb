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

      # Whether some checks passed but not all.
      #
      # @return [Boolean]
      def degraded?
        !healthy? && @results.any? { |r| r[:healthy] }
      end

      # Convert to a hash representation.
      #
      # @return [Hash] status hash with :status and :checks keys
      def to_h
        {
          status: if healthy?
                    'healthy'
                  else
                    (degraded? ? 'degraded' : 'unhealthy')
                  end,
          checks: @results
        }
      end
    end
  end
end
