<h1 align="center">🏚 shed</h1>

`shed` implements cross service timeout propagation and load-shedding for your
`rack` based services and `faraday` based clients.

Cross service timeout propagation and load-shedding improve the availability of
your services under load by reserving resource for requests that are still
meaningful to the requesting client (i.e. requests where the client hasn't
timed-out yet). `shed` does this by propagating the client timeout across
service calls via the `X-Client-Timeout-Ms` request header. Servers can then
decide, based on the timeout whether the request is worth processing at all
(i.e. has the request been queueing for longer than its timeout) and also check
throughout the lifetime of the request how long is left to process this request
within the clients declared timeout.

`shed` implements this via a pair of `Rack` and `Faraday` middlewares
(`Shed::RackMiddleware` and `Shed::FaradayMiddleware`).

For `rails` apps making use of `ActiveRecord` to manage database connections,
`Shed::ActiveRecord::Adapter` implements support for checking
`Shed.ensure_time_left!` before making any query to the database. This does
_not_ currently implement support for propagating `Shed.time_left_ms` to the
database query itself, yet.

## Installing

```ruby
# Gemfile

# Fetching the latest release
source "https://rubygems.pkg.github.com/cga1123" do
  gem "shed"
end

# Fetching the latest HEAD
gem "shed", github: "CGA1123/shed", glob: "ruby/shed.gemspec"
```
