# frozen_string_literal: true

# `Shed` implements client and server middlewares enabling cross-service
# timeout propagation and load-shedding in order to improve the performance and
# reliability of your services by mitigating cascading failures in scenarios
# where a services experience increased latency.
module Shed
  autoload :FaradayMiddleware, "shed/faraday_middleware"
  autoload :RackMiddleware, "shed/rack_middleware"
  autoload :HerokuDelta, "shed/heroku_delta"
  autoload :ActiveRecord, "shed/active_record"
  autoload :PostgreSQLConnection, "shed/postgresql_connection"

  # {Timeout} will be raised when calling {Shed.ensure_time_left!} with no time
  # left in the current request.
  Timeout = Class.new(StandardError)

  # {RACK_HTTP_HEADER} defines the Rack representation of the
  # `X-Client-Timeout-Ms` header used for timeout propagation.
  RACK_HTTP_HEADER = "HTTP_X_CLIENT_TIMEOUT_MS"

  # {HTTP_HEADER} defines the canonical HTTP header used to propagate client
  # timeouts across services.
  HTTP_HEADER = "X-Client-Timeout-Ms"

  # {KEY} defines the key for the fiber-local variable containing the current
  # deadline.
  KEY = "__shed"
  private_constant :KEY

  class << self
    # {register_faraday_middleware!} registers {Shed::FaradayMiddleware} on
    # `Faraday::Request`, allowing it to be used in faraday connections.
    def register_faraday_middleware!
      Faraday::Request.register_middleware(
        shed: Shed::FaradayMiddleware
      )
    end

    # {timeout_set?} returns whether there is a timeout set in the current
    # context.
    #
    # @return [Boolean]
    def timeout_set?
      !!store[KEY]
    end

    # {with_timeout} sets the timeout deadline for the current context.
    #
    # By default will only allow setting a new timeout with a deadline that is
    # _earlier_ than the currently configured deadline. This behaviour can be
    # overriden by setting `force: true` to extend the deadline.
    #
    # @param ms [Integer] the timeout in milliseconds.
    # @param force: [Boolean] whether to force the current timeout.
    # @return [void]
    def with_timeout(ms, force: false)
      deadline = (now_ms + ms.to_i)

      return unless earlier?(deadline) || force

      store[KEY] = deadline
    end

    # {clear_timeout} will clear any timeout set in the current context.
    #
    # @return [void]
    def clear_timeout
      store[KEY] = nil
    end

    # {time_left_ms} will return the duration left in the current timeout
    # period (in milliseconds).
    #
    # Returns `nil` if no timeout has been set.
    #
    # @return [Integer, nil]
    def time_left_ms
      return unless timeout_set?

      ms = store[KEY] - now_ms
      if ms < 0
        0
      else
        ms
      end
    end

    # {ensure_time_left!} raises {Timeout} if there is no {time_left?} based on
    # the configured timeout.
    #
    # Does not raise if no timeout has been configured.
    #
    # @raise [Timeout]
    def ensure_time_left!
      raise Timeout unless time_left?
    end

    # {time_left?} returns whether there is any time left in based on the
    # configured timeout.
    #
    # Always returns `true` when no timeout is set.
    #
    # @return [Boolean]
    def time_left?
      return true unless timeout_set?

      (now_ms < store[KEY])
    end

    private

    def earlier?(deadline)
      return true unless timeout_set?

      deadline < store[KEY]
    end

    def store
      Thread.current
    end

    def now_ms
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000.0).to_i
    end
  end
end
