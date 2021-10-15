# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shed::ActiveRecord::Adapter do
  let(:klass) do
    Class.new do
      attr_reader :calls

      def initialize
        @calls = []
      end

      def respond_to_missing?(method_name, include_private = false)
        %w[execute exec_query exec_insert exec_delete exec_update].include?(method_name)
      end

      def method_missing(method, *args)
        @calls << [method, args]
      end
    end.prepend(described_class)
  end

  let(:adapter) { klass.new }

  describe "#exec_query" do
    context "with no timeout set" do
      it "calls the underlying adapter" do
        adapter.exec_query("SELECT 1")

        expect(adapter.calls).to eq([[:exec_query, ["SELECT 1", nil, [], {prepare: false}]]])
      end
    end

    context "with a timeout set" do
      context "when exceeded" do
        after { Shed.clear_timeout }
        before do
          allow(Process).to receive(:clock_gettime).and_return(1.0, 2.1)
          Shed.with_timeout(1000)
        end

        it "raises a Shed::Timeout error" do
          expect { adapter.exec_query("SELECT 1") }.to raise_error(Shed::Timeout)
          expect(adapter.calls).to be_empty
        end
      end

      context "when not exceeded" do
        it "calls the underlying adapter" do
          adapter.exec_query("SELECT 1")

          expect(adapter.calls).to eq([[:exec_query, ["SELECT 1", nil, [], {prepare: false}]]])
        end
      end
    end
  end

  [
    [:execute, ["SELECT 1", nil]],
    [:exec_insert, ["SELECT 3", nil, [], nil, nil]],
    [:exec_delete, ["SELECT 4", nil, []]],
    [:exec_update, ["SELECT 5", nil, []]]
  ].each do |method, args|
    describe "##{method}" do
      context "with no timeout set" do
        it "calls the underlying adapter" do
          adapter.send(method, *args)

          expect(adapter.calls).to eq([[method, args]])
        end
      end

      context "with a timeout set" do
        context "when exceeded" do
          after { Shed.clear_timeout }
          before do
            allow(Process).to receive(:clock_gettime).and_return(1.0, 2.1)
            Shed.with_timeout(1000)
          end

          it "raises a Shed::Timeout error" do
            expect { adapter.send(method, *args) }.to raise_error(Shed::Timeout)
            expect(adapter.calls).to be_empty
          end
        end

        context "when not exceeded" do
          it "calls the underlying adapter" do
            adapter.send(method, *args)

            expect(adapter.calls).to eq([[method, args]])
          end
        end
      end
    end
  end
end
