<h1 align="center">🏚 shed</h1>
<p align="center">
  <a href="https://pkg.go.dev/github.com/CGA1123/shed">
    <img src="https://pkg.go.dev/badge/github.com/CGA1123/shed.svg" alt="Go Reference">
  </a>

  <a href="https://github.com/CGA1123/shed/actions/workflows/go.yml">
    <img src="https://github.com/CGA1123/shed/actions/workflows/go.yml/badge.svg" alt="Go CI Status">
  </a>
</p>
<p align="center">
  <a href="https://github.com/CGA1123/shed/actions/workflows/ruby.yml">
    <img src="https://github.com/CGA1123/shed/actions/workflows/ruby.yml/badge.svg" alt="Ruby CI Status">
  </a>
</p>

`shed` is a `Go` and `Ruby` library implementing cross-service timeout
propagation and load shedding.


**note**: still under development.

## What?

timeout propagation means advertising the client-side timeout for HTTP
requests. `shed` uses the `X-Client-Timeout-Ms` header to do this.

load shedding means dropping requests early when under load in order to free up
resources. This can be done throughout the lifetime of the request, or before
processing the request (e.g. if the request has been queued for longer than its
client timeout).

## Why?

Uncontrolled performance degradation of a service can quickly lead to resource
exhaustion and cascading failures. Client progations and load-shedding along
with other techniques (such as setting appropriate timeouts, retries, circuit
breakers, etc.) can improve the manner in which your service fail under load.

Propagating client timeouts and shedding requests based on this allows your
services to make more informed decisions about which requests are still worth
processing, saving your limited and already over-utilised resources for
requests that are still meaningful to process. This avoid wasted resources,
improves availability under load, and speeds up recovery times by controlling
request queueing.

In experiment run in [CGA1123/loadshedding-experiment-ruby] load-shedding
across a single service hop with client timeout propagation improved
availability of services by a factor of 10 under load.


[CGA1123/loadshedding-experiment-ruby]: https://github.com/CGA1123/loadshedding-experiment-ruby
