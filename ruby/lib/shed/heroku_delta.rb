# frozen_string_literal: true

module Shed
  RACK_HTTP_START_HEADER = "HTTP_X_REQUEST_START"

  HerokuDelta = ->(env) do
    now_ms = (Time.now.to_f * 1000).to_i
    started_at_ms = env[RACK_HTTP_START_HEADER].to_i

    if started_at_ms.zero? || started_at_ms > now_ms
      0
    else
      now_ms - started_at_ms
    end
  end
end
