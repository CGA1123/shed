# frozen_string_literal: true

require "spec_helper"

# TODO integration tests
# SELECTs, INSERTs, UPDATEs
RSpec.describe Shed::ActiveRecord::MySQL2 do
  context "unit" do
    let(:klass) do
      Class.new do
        attr_reader :calls

        def initialize
          @calls = []
        end

        def execute(sql, name = nil)
          @calls << [sql, name]
        end
      end
    end

    describe "#execute" do
      context "with a shed timeout set" do
        before { Shed.with_timeout(1000) }
        after { Shed.clear_timeout }

        it "adds MAX_EXECUTION_TIME annotations for SELECT" do
          klass.prepend(described_class)

          conn = klass.new

          conn.execute("SELECT 1", "NAME")
          conn.execute("select 1", "NAME")

          expect(conn.calls).to eq(
            [
              ["SELECT /*+ MAX_EXECUTION_TIME(1000) */ 1", "NAME"],
              ["select /*+ MAX_EXECUTION_TIME(1000) */ 1", "NAME"]
            ]
          )
        end

        it "does not add MAX_EXECUTION_TIME annotations for UPDATE" do
          klass.prepend(described_class)

          conn = klass.new

          conn.execute("UPDATE foo SET bar = 1", "NAME")
          conn.execute("update bar SET foo = 0", "NAME")

          expect(conn.calls).to eq(
            [
              ["UPDATE foo SET bar = 1", "NAME"],
              ["update bar SET foo = 0", "NAME"]
            ]
          )
        end
      end

      context "without a shed timeout set" do
        it "does not add any annotations" do
          klass.prepend(described_class)

          conn = klass.new

          conn.execute("SELECT 1", "NAME")
          conn.execute("select 1", "NAME")

          expect(conn.calls).to eq(
            [
              ["SELECT 1", "NAME"],
              ["select 1", "NAME"]
            ]
          )
        end
      end
    end
  end
end
