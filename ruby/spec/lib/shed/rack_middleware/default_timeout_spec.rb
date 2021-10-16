# frozen_string_literal: true

require "spec_helper"
require "rack"

RSpec.describe Shed::RackMiddleware::DefaultTimeout do
  after { Shed.clear_timeout }

  context "by default" do
    it "does not set a timeout" do
      app = ->(env) do
        expect(Shed.timeout_set?).to eq(false)

        [200, {}, [""]]
      end

      requestor = Rack::MockRequest.new(described_class.new(app))

      response = requestor.get("/")

      expect(response.status).to eq(200)
    end
  end

  context "when timeout_ms returns a non-nil value" do
    before { allow(Process).to receive(:clock_gettime).and_return(1.0) }

    it "sets a timeout" do
      timeout_ms = ->(_) { 2_000 }
      app = ->(env) do
        expect(Shed.timeout_set?).to eq(true)
        expect(Shed.time_left_ms).to eq(2_000)

        [200, {}, [""]]
      end

      requestor = Rack::MockRequest.new(
        described_class.new(app, timeout_ms: timeout_ms)
      )

      response = requestor.get("/")

      expect(response.status).to eq(200)
    end
  end
end
