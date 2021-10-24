# frozen_string_literal: true

require "spec_helper"
require "active_record"

RSpec.describe Shed::ActiveRecord::MySQL2OptimizerHints do
  after { Shed.clear_timeout }

  let(:klass) do
    Class.new do
      def initialize(current)
        @current = current
      end

      def optimizer_hints_values
        @current
      end
    end.prepend(described_class)
  end

  context "with a timeout" do
    before do
      allow(Process).to receive(:clock_gettime).and_return(1.0)
      Shed.with_timeout(1000)
    end

    [
      ["with no other hints", [], ["MAX_EXECUTION_TIME(1000)"]],
      ["with other hints", ["SOMETHING_ELSE"], ["SOMETHING_ELSE", "MAX_EXECUTION_TIME(1000)"]],
      ["with another MAX_EXECUTION_TIME hint", ["MAX_EXECUTION_TIME(500)"], ["MAX_EXECUTION_TIME(500)"]]
    ].each do |name, current, expected|
      context name do
        it "returns the expected optimizer_hints_values" do
          actual = klass.new(current).optimizer_hints_values

          expect(actual).to eq(expected)
        end
      end
    end
  end

  context "without a timeout" do
    [
      ["with no other hints", [], []],
      ["with other hints", ["SOMETHING_ELSE"], ["SOMETHING_ELSE"]],
      ["with another MAX_EXECUTION_TIME hint", ["MAX_EXECUTION_TIME(500)"], ["MAX_EXECUTION_TIME(500)"]]
    ].each do |name, current, expected|
      context name do
        it "returns the expected optimizer_hints_values" do
          actual = klass.new(current).optimizer_hints_values

          expect(actual).to eq(expected)
        end
      end
    end
  end

  context "with a real connection" do
    let(:model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "posts"
      end
    end

    before do
      ActiveRecord::Base.establish_connection(
        adapter: "mysql2",
        database: "shed_test",
        username: "root",
        password: "password",
        host: "127.0.0.1",
        port: "3306"
      )

      ActiveRecord::Base.connection.create_table("posts", force: true) do |t|
        t.string :title
        t.timestamps
      end

      ActiveRecord::Relation.prepend(described_class)
      model.all.to_a
    end

    context "without timeout" do
      it "doesn't set MAX_EXECUTION_TIME optimizer hint" do
        queries = []
        callback = lambda { |*args| queries << args.last[:sql] }

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          model.all.load
        end

        expect(queries).to eq(["SELECT `posts`.* FROM `posts`"])
      end

      it "preserves other hints" do
        queries = []
        callback = lambda { |*args| queries << args.last[:sql] }

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          model.optimizer_hints("NO_INDEX_MERGE(posts)").all.load
        end

        expect(queries).to eq(["SELECT /*+ NO_INDEX_MERGE(posts) */ `posts`.* FROM `posts`"])
      end
    end

    context "with timeout" do
      before do
        allow(Process).to receive(:clock_gettime).and_return(1.0)
        Shed.with_timeout(1000)
      end

      it "sets MAX_EXECUTION_TIME optimizer hint" do
        queries = []
        callback = lambda { |*args| queries << args.last[:sql] }

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          model.all.load
        end

        expect(queries).to eq(["SELECT /*+ MAX_EXECUTION_TIME(1000) */ `posts`.* FROM `posts`"])
      end

      it "preserves other hints" do
        queries = []
        callback = lambda { |*args| queries << args.last[:sql] }

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          model.optimizer_hints("NO_INDEX_MERGE(posts)").all.load
        end

        expect(queries).to eq(["SELECT /*+ MAX_EXECUTION_TIME(1000) NO_INDEX_MERGE(posts) */ `posts`.* FROM `posts`"])
      end
    end
  end
end
