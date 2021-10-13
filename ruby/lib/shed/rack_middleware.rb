# frozen_string_literal: true

module Shed
  # {RackMiddleware} implements a rack middleware which uses
  # {Shed.with_timeout} to propagate client timeouts advertised via
  # {Shed::HTTP_HEADER} to the request context.
  class RackMiddleware
    # {TIMEOUT_APP} implements the default `on_timeout` application, returning
    # and empty 503 response.
    TIMEOUT_APP = ->(_) { [503, {}, [""]] }

    # {NO_DELTA} implements the default `delta` functions, which always returns
    # 0, thus not adjusting the request timeout at all.
    #
    # @see HerokuDelta
    NO_DELTA = ->(_) { 0 }

    # @param app The next rack middleware/app in the chain.
    # @param on_timeout: The rack application to call when a timeout occurs.
    # @param delta: A callable object which given the current rack environment
    #   returns a duration in milliseconds to adjust the current timeout by.
    def initialize(app, on_timeout: TIMEOUT_APP, delta: NO_DELTA)
      @app = app
      @on_timeout = on_timeout
      @delta = delta
    end

    # {call} processes the current rack request.
    #
    # If the current request has a propagated timeout it will be set via
    # {Shed.with_timeout}.
    #
    # If the timeout has already been exceeded (via an adjustment computed by
    # the `delta` function, the `on_timeout` app will be called immediately.
    #
    # Else, the middleware passes control onto the next middleware or application.
    #
    # If any downstread middleware or application raises {Shed::Timeout}, this
    # middleware will rescue this error and call the `on_timeout` app.
    def call(env)
      with_timeout(env)

      if Shed.time_left?
        @app.call(env)
      else
        @on_timeout.call(env)
      end
    rescue Shed::Timeout
      @on_timeout.call(env)
    ensure
      Shed.clear_timeout
    end

    private

    def with_timeout(env)
      from_header = env[Shed::RACK_HTTP_HEADER]
      from_delta = @delta.call(env)

      return unless from_header

      Shed.with_timeout(from_header.to_i - from_delta)
    end
  end
end
