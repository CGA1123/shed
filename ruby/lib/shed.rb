# frozen_string_literal: true

module Shed
  autoload :FaradayMiddleware, "shed/faraday_middleware"
  autoload :RackMiddleware, "shed/rack_middleware"

  Timeout = Class.new(StandardError)

  RACK_HTTP_HEADER = "HTTP_X_CLIENT_TIMEOUT_MS"
  HTTP_HEADER = "X-Client-Timeout-Ms"
  KEY = "__shed"

  class << self
    def timeout_set?
      !!store[KEY]
    end

    def with_timeout(ms)
      store[KEY] = (now_ms + ms.to_i)
    end

    def clear_timeout
      store[KEY] = nil
    end

    def time_left_ms
      return unless timeout_set?

      ms = store[KEY] - now_ms
      if ms < 0
        0
      else
        ms
      end
    end

    def ensure_time_left!
      raise Timeout unless time_left?
    end

    def time_left?
      return true unless timeout_set?

      (now_ms < store[KEY])
    end

    private

    def store
      Thread.current
    end

    def now_ms
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000.0).to_i
    end
  end
end
