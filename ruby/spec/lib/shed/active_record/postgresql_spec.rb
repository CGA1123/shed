# frozen_string_literal: true

require "spec_helper"
require "active_record"
require "active_support/notifications"
require "active_record/connection_adapters/postgresql_adapter"

# TODO: INSERTs, UPDATEs
RSpec.describe Shed::ActiveRecord::PostgreSQL do
  context "integration" do
    before do
      ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(described_class)
      ::ActiveRecord::Base.logger = Logger.new(STDOUT)
      ::ActiveRecord::Base.establish_connection(
        adapter: "postgresql",
        url: "postgresql://localhost:5432/shed_test?sslmode=disable"
      )

      ::ActiveRecord::Schema.define do
        create_table :posts, force: true do |t|
          t.string :content
        end
      end

      posts.create!(content: "hello")
      posts.all.to_a
    end

    let(:posts) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "posts"
      end
    end

    context "with a timeout" do
      before { Shed.with_timeout(1000) }
      after { Shed.clear_timeout }

      it "set and clears up connection timeouts" do
        calls = []
        ActiveSupport::Notifications.subscribed(->(_, _, _, _, data) { calls << data[:sql] }, "sql.active_record") do
          p = posts.all.to_a
          expect(p.count).to eq(1)
        end

        expect(calls.count).to eq(3)
        expect(calls.first).to eq("SET SESSION statement_timeout TO 1000")
        expect(calls.last).to eq("SET SESSION statement_timeout TO DEFAULT")
      end
    end

    context "with no timeout" do
      it "does not set or clear connection timeouts" do
        calls = []
        ActiveSupport::Notifications.subscribed(->(_, _, _, _, data) { calls << data[:sql] }, "sql.active_record") do
          p = posts.all.to_a
          expect(p.count).to eq(1)
        end

        expect(calls.count).to eq(1)
      end
    end
  end

  context "unit" do
    let(:klass) do
      Class.new do
        attr_reader :calls

        def initialize(statement_timeout: nil)
          @config = {variables: {statement_timeout: statement_timeout}}
          @calls = []
        end

        def execute(sql, name = nil)
          @calls << [sql, name]
        end

        def exec_query(sql, name = nil, binds = [], prepare: false)
          @calls << [sql, name, binds, prepare]
        end
      end
    end

    describe "#exec_query" do
      context "without a shed timeout set" do
        it "does not wrap execution with calls to set and reset statement_timeout" do
          klass.prepend(described_class)

          conn = klass.new

          conn.exec_query("SELECT 1", "NAME")

          expect(conn.calls).to eq(
            [
              ["SELECT 1", "NAME", [], false]
            ]
          )
        end
      end

      context "with a shed timeout set" do
        before { Shed.with_timeout(1000) }
        after { Shed.clear_timeout }

        it "wraps execution with calls to set and resets statement_timeout default without a connection timeout" do
          klass.prepend(described_class)

          conn = klass.new

          conn.exec_query("SELECT 1", "NAME")

          expect(conn.calls).to eq(
            [
              ["SET SESSION statement_timeout TO 1000", nil, [], false],
              ["SELECT 1", "NAME", [], false],
              ["SET SESSION statement_timeout TO DEFAULT", nil, [], false]
            ]
          )
        end

        it "wraps execution with calls to set and resets statement_timeout with a connection timeout" do
          klass.prepend(described_class)

          conn = klass.new(statement_timeout: 10_000)

          conn.exec_query("SELECT 1", "NAME")

          expect(conn.calls).to eq(
            [
              ["SET SESSION statement_timeout TO 1000", nil, [], false],
              ["SELECT 1", "NAME", [], false],
              ["SET SESSION statement_timeout TO 10000", nil, [], false]
            ]
          )
        end
      end
    end

    describe "#execute" do
      context "without a shed timeout set" do
        it "does not wrap execution with calls to set and reset statement_timeout" do
          klass.prepend(described_class)

          conn = klass.new

          conn.execute("SELECT 1", "NAME")

          expect(conn.calls).to eq(
            [
              ["SELECT 1", "NAME"]
            ]
          )
        end
      end

      context "with a shed timeout set" do
        before { Shed.with_timeout(1000) }
        after { Shed.clear_timeout }

        it "wraps execution with calls to set and resets statement_timeout default without a connection timeout" do
          klass.prepend(described_class)

          conn = klass.new

          conn.execute("SELECT 1", "NAME")

          expect(conn.calls).to eq(
            [
              ["SET SESSION statement_timeout TO 1000", nil],
              ["SELECT 1", "NAME"],
              ["SET SESSION statement_timeout TO DEFAULT", nil]
            ]
          )
        end

        it "wraps execution with calls to set and resets statement_timeout with a connection timeout" do
          klass.prepend(described_class)

          conn = klass.new(statement_timeout: 10_000)

          conn.execute("SELECT 1", "NAME")

          expect(conn.calls).to eq(
            [
              ["SET SESSION statement_timeout TO 1000", nil],
              ["SELECT 1", "NAME"],
              ["SET SESSION statement_timeout TO 10000", nil]
            ]
          )
        end
      end
    end
  end
end
