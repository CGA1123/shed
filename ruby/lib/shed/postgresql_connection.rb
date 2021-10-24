# frozen_string_literal:true

module Shed
  module PostgreSQLConnection
    def exec(*args)
      return super unless Shed.timeout_set?

      with_timeout { send_query(*args) }
    end
    alias_method :async_exec, :exec

    def exec_params(*args)
      return super unless Shed.timeout_set?

      with_timeout { send_query_params(*args) }
    end
    alias_method :async_exec_params, :exec_params

    def exec_prepared(*args)
      return super unless Shed.timeout_set?

      with_timeout { send_query_prepared(*args) }
    end
    alias_method :async_exec_prepared, :exec_prepared

    private

    # {with_timeout} will block waiting for the connection to return a result
    # for up to {Shed.time_left_ms}.
    #
    # @raise [Shed::Timeout] if the timeout is exceeded.
    def with_timeout(&block)
      time_left_ms = Shed.time_left_ms
      Shed.ensure_time_left!

      block.call

      if block(time_left_ms / 1000.0) # seconds
        get_last_result
      else
        begin
          cancel
          get_last_result
        rescue PG::QueryCanceled
          raise Shed::Timeout
        end
      end
    end
  end
end
