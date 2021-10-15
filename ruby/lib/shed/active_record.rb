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
        ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(Adapter)
      end

      if defined?(::ActiveRecord::ConnectionAdapters::Mysql2Adapter)
        ::ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(Adapter)
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

      def exec_query(sql, name = nil, binds = [], prepare: false)
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
  end
end
