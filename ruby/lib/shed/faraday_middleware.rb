# frozen_string_literal: true

require "faraday"

module Shed
  class FaradayMiddleware < Faraday::Middleware
    def initialize(app)
      super(app)
    end

    def call(env)
      time_left_ms = timeout_ms(env)

      if time_left_ms
        env.request.timeout = (time_left_ms / 1000.0)
        env[:request_headers][Shed::HTTP_HEADER] = time_left_ms.to_s
      end

      @app.call(env)
    end

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
