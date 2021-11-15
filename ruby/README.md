<h1 align="center">🏚 shed</h1>

`shed` implements cross service timeout propagation and load-shedding for your
Ruby services!

Cross service timeout propagation and load-shedding improve the availability of
your services under load by reserving resource for requests that are still
meaningful to the requesting client (i.e. requests where the client hasn't
timed-out yet). `shed` does this by propagating the client timeout across
service calls via the `X-Client-Timeout-Ms` request header. Servers can then
decide, based on the timeout whether the request is worth processing at all
(i.e. has the request been queueing for longer than its timeout) and also check
throughout the lifetime of the request how long is left to process this request
within the clients declared timeout.

`shed` implements this by integrating with `rack`, `faraday`, `activerecord`,
`pg`, and `mysql2` gems in order to propgate a shared deadline through service
calls. This is (somewhat) analogous to deadline propation via the
`context.Context` package in Go.

For `rails` apps making use of `ActiveRecord` to manage database connections,
`Shed::ActiveRecord::Adapter` implements support for checking
`Shed.ensure_time_left!` before making any query to the database. This does
_not_ currently implement support for propagating `Shed.time_left_ms` to the
database query itself, yet.

## Getting Started

Add `shed` to your Gemfile:

```ruby
# for the latest release
source "https://rubygems.pkg.github.com/cga1123" do
  gem "shed"
end

# Fetching the latest HEAD
gem "shed", github: "CGA1123/shed", glob: "ruby/shed.gemspec"
```

Once the gem has been installed, `Shed::RackMiddleware::Propagate` and
`Shed::RackMiddleware::DefaultTimeout` can be used in order to set the deadline
either based on a propagated timeout from a client or based on some default
value. Or both, the lower shortest deadline will win.

For example:

```ruby
# frozen_string_literal: true

require "shed"

# Set a default upper bound deadline of 5_000ms, accounting for queueing.
use Shed::RackMiddleware::DefaultTimeout, timeout_ms: ->(env) { 5_000 - Shed::HerokuDelta.call(env) }

# Set the deadline based on the propagated request header, if set.
# Adjust the propagated timeout based on the observed queue time (as the
# difference between the X-Request-Start header and now, as set by Heroku).
use Shed::RackMiddleware::Propagate, delta: Shed::HerokuDelta

run ->(_env) { [200, {}, ["Hello, world!\n"]] }
```

If using `rails` the following initializer will set your database queries up to
respect deadlines, please consult the in-source module documentation for a
better understanding of how this will impact your queries to the database.

```ruby
# config/initializers/shed.rb
ActiveSupport.on_load(:active_record) do
  Shed::ActiveRecord.setup!
end
```

In order to propagate your timeout to other HTTP services use the `faraday`
middleware:

```ruby
Shed.register_faraday_middleware!

@connection = Faraday.new(url: "https://example.com") do |conn|
  conn.request :shed

  conn.adapter Faraday.default_adapter
end
```

This middleware will call `Shed.ensure_time_left!` before checking how long is
left in the current deadline and setting it as the faraday timeout and
propagating it via the `X-Client-Timeout-Ms` header.

If the connection already has a timeout set that is _lower_ than the current
time left in the deadline, it will be used instead.
