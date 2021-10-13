# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shed do
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
      Shed.with_timeout(10_000)
    end

    after { Shed.clear_timeout }

    it { expect(described_class.timeout_set?).to be true }
    it { expect(described_class.time_left_ms).to be 10_000 }
    it { expect(described_class.time_left?).to be true }
    it { expect { described_class.ensure_time_left! }.not_to raise_error }
  end

  context "with a timeout in the past set" do
    before do
      allow(Process).to receive(:clock_gettime).and_return(0.001)
      Shed.with_timeout(10_000)
      allow(Process).to receive(:clock_gettime).and_return(10.001)
    end

    after { Shed.clear_timeout }

    it { expect(described_class.timeout_set?).to be true }
    it { expect(described_class.time_left_ms).to be 0 }
    it { expect(described_class.time_left?).to be false }
    it { expect { described_class.ensure_time_left! }.to raise_error(Shed::Timeout) }
  end
end
