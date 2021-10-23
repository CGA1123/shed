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
        ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(
          PostgreSQLStatementTimeout
        )
      end

      if defined?(::ActiveRecord::ConnectionAdapters::Mysql2Adapter)
        ::ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(Adapter)
        ::ActiveRecord::Relation.prepend(MySQL2OptimizerHints)
      end

      if defined?(::ActiveRecord::ConnectionAdapters::SQLite3Adapter)
        ::ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(Adapter)
      end
    end

    # {Adapter} implements support for {Shed} timeouts/deadlines checking for
    # any `ActiveRecord::ConnectionAdapters`.
    #
    # It is intended to be prepended to the connection adapter in use by the
    # application, it will check if the current deadline is exceeded via
    # {Shed.ensure_time_left!} before calling the underlying querying function.
    #
    # This does not prevent a specific query from over-running the
    # {Shed.time_left_ms} as it does _not_ set any specific timeout on the
    # connection or for the query. The default timeout values are respected and
    # should be set.
    module Adapter
      def execute(sql, name = nil)
        Shed.ensure_time_left!

        super
      end

      def exec_query(sql, name = nil, binds = [], prepare: false, async: false)
        Shed.ensure_time_left!

        super
      end

      def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil)
        Shed.ensure_time_left!

        super
      end

      def exec_delete(sql, name = nil, binds = [])
        Shed.ensure_time_left!

        super
      end

      def exec_update(sql, name = nil, binds = [])
        Shed.ensure_time_left!

        super
      end
    end

    # {PostgreSQLStatementTimeout} is intended to be prepended to
    # `ActiveRecord::ConnectionAdapters::PostgreSQLAdapter`.
    #
    # It executes all calls via ruby-pg/libpq's async API before blocking with
    # a timeout. If a timeout is exceeded, the in progress query will be
    # cancelled, raising a PG::QueryCanceled error.
    module PostgreSQLStatementTimeout
      def query(sql, name = nil)
        return super unless Shed.timeout_set?

        time_left_ms = Shed.time_left_ms
        Shed.ensure_time_left!

        materialize_transactions
        mark_transaction_written_if_write(sql)

        log(sql, name) do
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
            @connection.send_query(sql)

            shed_await_result(@connection, timeout_ms: time_left_ms)
              .map_types!(@type_map_for_results)
              .values
          end
        end
      end

      def execute(sql, name = nil)
        return super unless Shed.timeout_set?

        sql = transform_query(sql)
        check_if_write_query(sql)

        materialize_transactions
        mark_transaction_written_if_write(sql)

        log(sql, name) do
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
            @connection.send_query(sql)

            shed_await_result(@connection, timeout_ms: time_left_ms)
          end
        end
      end

      def exec_no_cache(sql, name, binds, async: false)
        return super unless Shed.timeout_set?

        time_left_ms = Shed.time_left_ms
        Shed.ensure_time_left!

        materialize_transactions
        mark_transaction_written_if_write(sql)

        # make sure we carry over any changes to ActiveRecord.default_timezone
        # that have been made since we established the connection
        update_typemap_for_default_timezone

        type_casted_binds = type_casted_binds(binds)
        log(sql, name, binds, type_casted_binds, async: async) do
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
            @connection.send_query_params(sql, type_casted_binds)

            shed_await_result(@connection, timeout_ms: time_left_ms)
          end
        end
      end

      def exec_cache(sql, name, binds, async: false)
        return super unless Shed.timeout_set?

        time_left_ms = Shed.time_left_ms
        Shed.ensure_time_left!

        materialize_transactions
        mark_transaction_written_if_write(sql)
        update_typemap_for_default_timezone

        stmt_key = prepare_statement(sql, binds)
        type_casted_binds = type_casted_binds(binds)

        log(sql, name, binds, type_casted_binds, stmt_key, async: async) do
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
            @connection.send_query_prepared(stmt_key, type_casted_binds)

            shed_await_result(@connection, timeout_ms: time_left_ms)
          end
        end
      rescue ActiveRecord::StatementInvalid => e
        raise unless is_cached_plan_failure?(e)

        # Nothing we can do if we are in a transaction because all commands
        # will raise InFailedSQLTransaction
        if in_transaction?
          raise ActiveRecord::PreparedStatementCacheExpired.new(e.cause.message)
        else
          @lock.synchronize do
            # outside of transactions we can simply flush this query and retry
            @statements.delete sql_key(sql)
          end
          retry
        end
      end

      private

      # {shed_await_result} will block waiting for the connection to return a
      # result for up to {timeout_ms}.
      #
      # @param cnx [PG::Connection] the connection to the database.
      # @param timeout_ms: [Numeric] the timeout (in milliseconds) to block for.
      # @raise [Shed::Timeout] if the timeout is exceeded.
      def shed_await_result(cnx, timeout_ms:)
        if cnx.block(timeout_ms / 1000.0) # seconds
          cnx.get_last_result
        else
          begin
            cnx.cancel
            cnx.get_last_result
          rescue PG::QueryCanceled
            raise Shed::Timeout
          end
        end
      end
    end

    # {MySQL2OptimizerHints} is intended to be prepended to
    # `ActiveRecord::Relation`, it will cause all queries to have the
    # `MAX_EXECUTION_TIME` optimizer hint added, propagating the current
    # deadline (if set) to the database.
    #
    # @note MySQL only supports MAX_EXECUTION_TIME for SELECT queries, it will
    #   silently ignore this timeout for other queries.
    module MySQL2OptimizerHints
      def optimizer_hints_values
        current = super

        if Shed.timeout_set? && !current.find { |v| v =~ /MAX_EXECUTION_TIME/ }
          current += ["MAX_EXECUTION_TIME(#{Shed.time_left_ms})"]
        end

        current
      end
    end
  end
end
