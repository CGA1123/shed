# frozen_string_literal: true

module Shed
  # {HerokuDelta} implements a delta function for use in applications deployed
  # to Heroku.
  #
  # Heroku sets the `X-Request-Start` header when ingesting request in its
  # routing-layer. The value of this header is the UNIX timestamp (in
  # milliseconds) at which the request is processed.
  #
  # In scenarios where the ruby webservers are under load requests will be
  # queued. This delta calculator ensures that the queue time is taken into
  # account when setting the timeout for the current timeout.
  class HerokuDelta
    # {RACK_HTTP_START_HEADER} contains the rack definition of the
    # `X-Request-Start` HTTP header set by Heroku when receiving a request.
    RACK_HTTP_START_HEADER = "HTTP_X_REQUEST_START"

    # {call} returns the duration (in milliseconds) between the current time
    # and the time Heroku received this requested. Effectively measuring queue
    # time.
    #
    # Handles cases where the header is missing or clock-drift leads to the
    # header being in the future by returning 0.
    #
    # @param env [Hash] The rack request env hash.
    def self.call(env)
      now_ms = (Time.now.to_f * 1000).to_i
      started_at_ms = env[RACK_HTTP_START_HEADER].to_i

      if started_at_ms.zero? || started_at_ms > now_ms
        0
      else
        now_ms - started_at_ms
      end
    end
  end
end
