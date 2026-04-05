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
    @previous_status = nil

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
      status = Status.new(results)

      new_status = status.to_h[:status]
      new_status_sym = new_status.to_sym
      if @configuration.on_change_callback && @previous_status && @previous_status != new_status_sym
        @configuration.on_change_callback.call(@previous_status, new_status_sym)
      end
      @previous_status = new_status_sym

      status
    end

    # Run a single named health check and return its result hash.
    #
    # @param name [Symbol, String] the name of the check to run
    # @return [Hash] result with :name, :healthy, :duration, and optionally :error
    # @raise [Error] if no check with the given name exists
    def self.check_one(name)
      check_obj = @configuration.checks.find { |c| c.name.to_s == name.to_s }
      raise Error, "unknown check: #{name}" unless check_obj

      check_obj.call
    end

    # Reset all configured checks.
    #
    # @return [void]
    def self.reset!
      @configuration = Configuration.new
      @previous_status = nil
    end
  end
end
