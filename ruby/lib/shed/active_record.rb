# frozen_string_literal:true

module Shed
  # {ActiveRecord} defines modules for common
  # `ActiveRecord::ConnectionAdapters` which can be prepended in order to
  # respec timeouts/deadlines set by {Shed}.
  module ActiveRecord
    # {setup!} prepends the appropriate {Shed::ActiveRecord} module to their
    # corresponding `ActiveRecord::ConnectionAdapters` class.
    def self.setup!
      if defined?(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
        ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(PostgreSQL)
      end

      if defined?(::ActiveRecord::ConnectionAdapters::Mysql2Adapter)
        ::ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(MySQL2)
      end
    end

    # {PostgreSQL} implements support for {Shed} timeouts/deadlines for the
    # `PostgreSQLAdapter`.
    #
    # @todo Do other execution methods need to be prepended? (exec_query and so on?)
    module PostgreSQL
      # {execute} wraps any calls to `execute` with a pair of statements to set
      # and reset the `statement_timeout` session variable on the current
      # connection.
      #
      # @note This will not work as expected when using connection multiplexing
      #   via tools such as `PgBouncer` in `statement` or `transaction` mode.
      #   This is because we make use of `SESSION` level variables.
      def execute(sql, name = nil)
        return super unless Shed.timeout_set?

        time_left = Shed.time_left_ms
        Shed.ensure_time_left!

        begin
          super("SET SESSION statement_timeout TO #{time_left}")
          super
        ensure
          # TODO: should this be done by middleware instead as a callback?
          # Would reduce the # of db calls done if we _know_ that every call in
          # the given context (request) will call `SET SESSION statement_timeout`...
          if shed_default_statement_timeout
            super("SET SESSION statement_timeout TO #{shed_default_statement_timeout}")
          else
            super("SET SESSION statement_timeout TO DEFAULT")
          end
        end
      end

      # {exec_query} wraps any calls to `exec_query` with a pair of statements
      # to set and reset the `statement_timeout` session variable on the
      # current connection.
      #
      # @note This will not work as expected when using connection multiplexing
      #   via tools such as `PgBouncer` in `statement` or `transaction` mode.
      #   This is because we make use of `SESSION` level variables.
      def exec_query(sql, name = nil, binds = [], prepare: false)
        return super unless Shed.timeout_set?

        time_left = Shed.time_left_ms
        Shed.ensure_time_left!

        begin
          super("SET SESSION statement_timeout TO #{time_left}")
          super
        ensure
          # TODO: should this be done by middleware instead as a callback?
          # Would reduce the # of db calls done if we _know_ that every call in
          # the given context (request) will call `SET SESSION statement_timeout`...
          if shed_default_statement_timeout
            super("SET SESSION statement_timeout TO #{shed_default_statement_timeout}")
          else
            super("SET SESSION statement_timeout TO DEFAULT")
          end
        end
      end

      private

      def shed_default_statement_timeout
        return @shed_default_statement_timeout if defined?(@shed_default_statement_timeout)

        variables = @config.fetch(:variables, {})
        @shed_default_statement_timeout = variables["statement_timeout"] || variables[:statement_timeout]
      end
    end

    # {MySQL2} implements support for {Shed} timeouts/deadlines for the
    # `MySQL2` adapter.
    #
    # @todo Do other execution methods need to be prepended? (exec_query and so on?)
    module MySQL2
      # {execute} will add the `MAX_EXECUTION_TIME` optimizer_hint magic
      # comment to any SQL query begining with `select` or `SELECT`
      def execute(sql, name = nil)
        return super unless Shed.timeout_set?

        optimiser_hint = "/*+ MAX_EXECUTION_TIME(#{Shed.time_left_ms}) */"
        Shed.ensure_time_left!

        if sql.start_with?("select")
          sql = sql.sub("select", "select #{optimiser_hint}")
        end

        if sql.start_with?("SELECT")
          sql = sql.sub("SELECT", "SELECT #{optimiser_hint}")
        end

        super(sql, name)
      end
    end
  end
end
