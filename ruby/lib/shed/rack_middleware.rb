# frozen_string_literal: true

module Shed
  class RackMiddleware
    TIMEOUT_APP = ->(_) { [503, {}, []] }
    NO_DELTA = ->(_) { 0 }

    def initialize(app, on_timeout: TIMEOUT_APP, delta: NO_DELTA)
      @app = app
      @on_timeout = on_timeout
      @delta = delta
    end

    def call(env)
      with_timeout(env)

      if Shed.time_left?
        @app.call(env)
      else
        @on_timeout.call(env)
      end
    rescue Shed::Timeout
      @on_timeout.call(env)
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
