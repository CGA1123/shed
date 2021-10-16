# frozen_string_literal: true

require "spec_helper"
require "rack"

RSpec.describe Shed::RackMiddleware::Propagate do
  after { Shed.clear_timeout }

  context "when setting X-Client-Timeout-Ms" do
    before { allow(Process).to receive(:clock_gettime).and_return(1.0) }

    it "sets a shed timeout" do
      app = ->(env) do
        expect(Shed.timeout_set?).to eq(true)
        expect(Shed.time_left?).to eq(true)
        expect(Shed.time_left_ms).to eq(10_000)

        [200, {}, [""]]
      end

      requestor = Rack::MockRequest.new(described_class.new(app))

      response = requestor.get("/", {"HTTP_X_CLIENT_TIMEOUT_MS" => "10000"})

      expect(response.status).to eq(200)
    end
  end

  context "when setting an X-Client-Timeout-Ms with delta exceeding timeout" do
    it "sheds the request" do
      app = ->(_env) { [200, {}, [""]] }
      on_timeout = ->(_env) { [1123, {}, [""]] }
      delta = ->(_env) { 10_001 }

      requestor = Rack::MockRequest.new(described_class.new(app, delta: delta, on_timeout: on_timeout))

      response = requestor.get("/", {"HTTP_X_CLIENT_TIMEOUT_MS" => "10000"})

      expect(response.status).to eq(1123)
    end
  end

  context "when setting X-Client-Timeout-Ms and checking an expired timeout" do
    before { allow(Process).to receive(:clock_gettime).and_return(1.0, 11.0) }

    it "sheds the request" do
      on_timeout = ->(_env) { [1123, {}, [""]] }
      app = ->(_env) do
        # this makes a second call to clock_gettime, which has been stubbed to
        # return a time exactly 10_000ms after the initial call to set the
        # deadline.
        Shed.ensure_time_left!

        [200, {}, [""]]
      end

      requestor = Rack::MockRequest.new(described_class.new(app, on_timeout: on_timeout))

      response = requestor.get("/", {"HTTP_X_CLIENT_TIMEOUT_MS" => "10000"})

      expect(response.status).to eq(1123)
    end
  end

  context "when setting X-Client-Timeout-Ms and checking a non-expired timeout" do
    before { allow(Process).to receive(:clock_gettime).and_return(1.0, 10.999) }

    it "sheds the request" do
      on_timeout = ->(_env) { [1123, {}, [""]] }
      app = ->(_env) do
        # this makes a second call to clock_gettime, which has been stubbed to
        # return a time exactly 999ms after the initial call to set the
        # deadline.
        Shed.ensure_time_left!

        [200, {}, [""]]
      end

      requestor = Rack::MockRequest.new(described_class.new(app, on_timeout: on_timeout))

      response = requestor.get("/", {"HTTP_X_CLIENT_TIMEOUT_MS" => "10000"})

      expect(response.status).to eq(200)
    end
  end

  context "when not setting X-Client-Timeout-Ms" do
    it "does not set a shed timeout" do
      app = ->(env) do
        expect(Shed.timeout_set?).to eq(false)
        expect(Shed.time_left?).to eq(true)

        [200, {}, [""]]
      end

      requestor = Rack::MockRequest.new(described_class.new(app))

      response = requestor.get("/")

      expect(response.status).to eq(200)
    end
  end
end
