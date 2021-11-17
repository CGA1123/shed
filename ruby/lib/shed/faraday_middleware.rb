# frozen_string_literal: true

require "faraday"

module Shed
  # {FaradayMiddleware} implements a faraday middleware which propagates the
  # timeout left the current request to the destination host via the
  # `X-Client-Timeout-Ms` request header.
  class FaradayMiddleware < Faraday::Middleware
    # {call} sets the `X-Client-Timeout-Ms` to the lesser of the already
    # configured faraday timeout or the currently configured {Shed} timeout.
    #
    # @param env [Faraday::Env] the current request environment.
    # @return [Faraday::Response] The response to the request.
    def call(env)
      time_left_ms = timeout_ms(env)

      Shed.ensure_time_left!

      if time_left_ms
        env.request.timeout = (time_left_ms / 1000.0)
        env[:request_headers][Shed::HTTP_HEADER] = time_left_ms.to_s
      end

      @app.call(env)
    end

    private

    def timeout_ms(env)
      [
        request_timeout_ms(env),
        shed_timeout_ms
      ].compact.min
    end

    def request_timeout_ms(env)
      timeout_s = env.request.timeout
      return unless timeout_s

      timeout_s * 1000
    end

    def shed_timeout_ms
      return unless Shed.timeout_set?

      Shed.time_left_ms
    end
  end
end
