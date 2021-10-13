# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shed::FaradayMiddleware do
  let(:conn) do
    Faraday.new do |c|
      c.use described_class
      c.adapter :test do |stub|
        stub.get("/") do |env|
          [200, env.request_headers, [""]]
        end
      end
    end
  end

  context "without any timeout" do
    subject(:response) { conn.get("/") }

    it { expect(response.status).to eq(200) }
    it { expect(response.headers.keys).to contain_exactly("User-Agent") }
  end

  context "with a faraday timeout only" do
    subject(:response) { conn.get("/") }

    before { conn.options.timeout = 10 }

    it { expect(response.status).to eq(200) }
    it { expect(response.headers.keys).to contain_exactly("User-Agent", "X-Client-Timeout-Ms") }
    it { expect(response.headers["X-Client-Timeout-Ms"]).to eq("10000") }
  end

  context "with a shedding timeout only" do
    subject(:response) { conn.get("/") }

    before do
      allow(Process).to receive(:clock_gettime).and_return(1.0)
      Shed.with_timeout(10_000)
    end

    after { Shed.clear_timeout }

    it { expect(response.status).to eq(200) }
    it { expect(response.headers.keys).to contain_exactly("User-Agent", "X-Client-Timeout-Ms") }
    it { expect(response.headers["X-Client-Timeout-Ms"]).to eq("10000") }
  end

  context "with a faraday timeout shorter than a shed timeout" do
    subject(:response) { conn.get("/") }

    before do
      allow(Process).to receive(:clock_gettime).and_return(1.0)
      Shed.with_timeout(10_000)
      conn.options.timeout = 5
    end

    after { Shed.clear_timeout }

    it { expect(response.status).to eq(200) }
    it { expect(response.headers.keys).to contain_exactly("User-Agent", "X-Client-Timeout-Ms") }
    it { expect(response.headers["X-Client-Timeout-Ms"]).to eq("5000") }
  end

  context "with a shed timeout shorter than a faraday timeout" do
    subject(:response) { conn.get("/") }

    before do
      allow(Process).to receive(:clock_gettime).and_return(1.0)
      Shed.with_timeout(5_000)
      conn.options.timeout = 10
    end

    after { Shed.clear_timeout }

    it { expect(response.status).to eq(200) }
    it { expect(response.headers.keys).to contain_exactly("User-Agent", "X-Client-Timeout-Ms") }
    it { expect(response.headers["X-Client-Timeout-Ms"]).to eq("5000") }
  end
end
