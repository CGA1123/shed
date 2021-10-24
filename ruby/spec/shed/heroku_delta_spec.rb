# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shed::HerokuDelta do
  subject(:delta) { described_class.call(env) }

  [
    {
      name: "when X-Request-Start is not set",
      env: {},
      expected: 0
    },
    {
      name: "when X-Request-Start is not an integer",
      env: {"HTTP_X_REQUEST_START" => "foo"},
      expected: 0
    },
    {
      name: "when X-Request-Start is in the future",
      env: {"HTTP_X_REQUEST_START" => "10001"},
      expected: 0
    },
    {
      name: "when X-Request-Start is in the past",
      env: {"HTTP_X_REQUEST_START" => "5000"},
      expected: 5000
    }
  ].each do |test_case|
    context test_case.fetch(:name) do
      before { allow(Time).to receive(:now).and_return(now) }

      let(:now) { Time.at(10.000) }
      let(:env) { test_case.fetch(:env) }

      it { is_expected.to eq test_case.fetch(:expected) }
    end
  end
end
