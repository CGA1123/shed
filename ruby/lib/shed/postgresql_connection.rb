# frozen_string_literal:true

module Shed
  module PostgreSQLConnection
    # {WithDeadlinePropagation} adds support for deadline propagation to a
    # `PG::Connection` by patching synchronous query methods to make use of
    # `libpq`'s asynchronous non-blocking APIs to timeout and cancel any
    # ongoing query after {Shed.time_left_ms} has been exceeded.
    #
    # Query methods canceled due to exceeding their deadline will wrap any
    # `PG::QueryCanceled` as {Shed::Timeout}.
    module WithDeadlinePropagation
      def exec(*args, &block)
        return super unless Shed.timeout_set?

        with_timeout(block) { send_query(*args) }
      end
      alias_method :async_exec, :exec

      def exec_params(*args, &block)
        return super unless Shed.timeout_set?

        with_timeout(block) { send_query_params(*args) }
      end
      alias_method :async_exec_params, :exec_params

      def exec_prepared(*args, &block)
        return super unless Shed.timeout_set?

        with_timeout(block) { send_query_prepared(*args) }
      end
      alias_method :async_exec_prepared, :exec_prepared

      private

      def with_timeout(result_block, &query)
        time_left_ms = Shed.time_left_ms
        Shed.ensure_time_left!

        query.call

        timed_out = !block(time_left_ms / 1000.0)
        if timed_out
          cancel
        end

        begin
          result = get_last_result
          if result_block
            result_block.call(result)
          else
            result
          end
        rescue PG::QueryCanceled
          raise Shed::Timeout
        end
      end
    end

    # {Wrapper} provides a `SimpleDelegator` for a `PG::Connection` which
    # includes behaviour provided by {WithDeadlinePropagation}.
    class Wrapper < SimpleDelegator
      prepend WithDeadlinePropagation
    end
  end
end
