# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shed do
  after { described_class.clear_timeout }

  describe "::HTTP_HEADER" do
    it { expect(described_class::HTTP_HEADER).to eq("X-Client-Timeout-Ms") }
  end

  describe "::RACK_HTTP_HEADER" do
    it { expect(described_class::RACK_HTTP_HEADER).to eq("HTTP_X_CLIENT_TIMEOUT_MS") }
  end

  context "when no timeout is set" do
    it { expect(described_class.timeout_set?).to be false }
    it { expect(described_class.time_left_ms).to be nil }
    it { expect(described_class.time_left?).to be true }
    it { expect { described_class.ensure_time_left! }.not_to raise_error }
  end

  context "with a timeout in the future set" do
    before do
      allow(Process).to receive(:clock_gettime).and_return(0.001)
      described_class.with_timeout(10_000)
    end

    it { expect(described_class.timeout_set?).to be true }
    it { expect(described_class.time_left_ms).to be 10_000 }
    it { expect(described_class.time_left?).to be true }
    it { expect { described_class.ensure_time_left! }.not_to raise_error }
  end

  context "with a timeout in the past set" do
    before do
      allow(Process).to receive(:clock_gettime).and_return(0.001, 10.001)
      described_class.with_timeout(10_000)
    end

    it { expect(described_class.timeout_set?).to be true }
    it { expect(described_class.time_left_ms).to be 0 }
    it { expect(described_class.time_left?).to be false }
    it { expect { described_class.ensure_time_left! }.to raise_error(described_class::Timeout) }
  end

  describe "#with_timeout" do
    before { allow(Process).to receive(:clock_gettime).and_return(1.0) }

    it "does not set a higher than current timeout unless forced" do
      described_class.with_timeout(10_000)
      expect(described_class.time_left_ms).to eq(10_000)

      described_class.with_timeout(20_000)
      expect(described_class.time_left_ms).to eq(10_000)

      described_class.with_timeout(20_000, force: true)
      expect(described_class.time_left_ms).to eq(20_000)
    end
  end
end
