# frozen_string_literal: true

require "spec_helper"
require "pg"

RSpec.describe Shed::PostgreSQLConnection do
  after { Shed.clear_timeout }

  let(:opts) { {password: "postgres", dbname: "shed_test"} }
  let(:conn) { described_class::Wrapper.new(PG::Connection.new(opts)) }

  context "without any timeout" do
    describe "#exec" do
      it "returns the result of the query" do
        expect(conn.exec("SELECT 1").first).to eq({"?column?" => "1"})
      end

      it "returns the result of the block" do
        result = conn.exec("SELECT 1") do |r|
          r.first["?column?"]
        end

        expect(result).to eq("1")
      end

      it "does not timeout" do
        expect(conn.exec("SELECT pg_sleep(0.1)").first).to eq({"pg_sleep" => ""})
      end
    end

    describe "#exec_params" do
      it "returns the result of the query" do
        expect(conn.exec_params("SELECT $1", [5]).first).to eq({"?column?" => "5"})
      end

      it "returns the result of the block" do
        result = conn.exec_params("SELECT $1", [5]) do |r|
          r.first["?column?"]
        end

        expect(result).to eq("5")
      end

      it "does not timeout" do
        result = conn.exec_params("SELECT pg_sleep($1)", [0.1]).first
        expect(result).to eq({"pg_sleep" => ""})
      end
    end

    describe "#exec_prepared" do
      before do
        conn.prepare("test_select", "SELECT $1")
        conn.prepare("test_sleep", "SELECT pg_sleep($1)")
      end

      it "returns the result of the query" do
        result = conn.exec_prepared("test_select", [5]).first
        expect(result).to eq({"?column?" => "5"})
      end

      it "returns the result of the block" do
        result = conn.exec_prepared("test_select", [6]) do |r|
          r.first["?column?"]
        end

        expect(result).to eq("6")
      end

      it "does not timeout" do
        result = conn.exec_prepared("test_sleep", [0.1]).first
        expect(result).to eq({"pg_sleep" => ""})
      end
    end
  end

  context "with a timeout" do
    before { Shed.with_timeout(75) }

    describe "#exec" do
      it "returns the result of the query" do
        expect(conn.exec("SELECT 1").first).to eq({"?column?" => "1"})
      end

      it "returns the result of the block" do
        result = conn.exec("SELECT 1") do |r|
          r.first["?column?"]
        end

        expect(result).to eq("1")
      end

      it "does not timeout" do
        expect(conn.exec("SELECT pg_sleep(0.01)").first).to eq({"pg_sleep" => ""})
      end

      it "times out when exceeding deadline" do
        expect { conn.exec("SELECT pg_sleep(0.1)") }.to raise_error(Shed::Timeout)
      end
    end

    describe "#exec_params" do
      it "returns the result of the query" do
        expect(conn.exec_params("SELECT $1", [5]).first).to eq({"?column?" => "5"})
      end

      it "returns the result of the block" do
        result = conn.exec_params("SELECT $1", [5]) do |r|
          r.first["?column?"]
        end

        expect(result).to eq("5")
      end

      it "does not timeout" do
        result = conn.exec_params("SELECT pg_sleep($1)", [0.01]).first
        expect(result).to eq({"pg_sleep" => ""})
      end

      it "times out when exceeding deadline" do
        expect { conn.exec_params("SELECT pg_sleep($1)", [0.1]) }.to raise_error(Shed::Timeout)
      end
    end

    describe "#exec_prepared" do
      before do
        conn.prepare("test_select", "SELECT $1")
        conn.prepare("test_sleep", "SELECT pg_sleep($1)")
      end

      it "returns the result of the query" do
        result = conn.exec_prepared("test_select", [5]).first
        expect(result).to eq({"?column?" => "5"})
      end

      it "returns the result of the block" do
        result = conn.exec_prepared("test_select", [6]) do |r|
          r.first["?column?"]
        end

        expect(result).to eq("6")
      end

      it "does not timeout" do
        result = conn.exec_prepared("test_sleep", [0.01]).first
        expect(result).to eq({"pg_sleep" => ""})
      end

      it "times out when exceeding deadline" do
        expect { conn.exec_prepared("test_sleep", [0.1]) }.to raise_error(Shed::Timeout)
      end
    end
  end
end
