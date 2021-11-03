// Package shed implements client and server middleware to propagate and
// respect client timeouts between services.
package shed

import (
	"context"
	"net/http"
	"strconv"
	"time"
)

const (
	// Header contains the header key expected to be set by incoming requests
	// in order to propagate timeouts across the network, it is expected to be
	// a string parseable into an int64 which represents the timeout of the
	// client in milliseconds.
	Header = "X-Client-Timeout-Ms"
)

type roundTripper struct {
	next       http.RoundTripper
	maxTimeout int64
}

// RoundTrip wraps the given round tripper, setting the `X-Client-Timeout-Ms`
// on any request made to the number of milliseconds left until the request's
// context deadline will be exceeded.
func (rt *roundTripper) RoundTrip(r *http.Request) (*http.Response, error) {
	millisecondsLeft := rt.millisecondsLeft(r.Context())
	if millisecondsLeft > 0 {
		r.Header.Add(Header, strconv.FormatInt(millisecondsLeft, 10))
	}

	return rt.next.RoundTrip(r)
}

func (rt *roundTripper) millisecondsLeft(ctx context.Context) int64 {
	deadlineMs := int64(0)
	deadline, ok := ctx.Deadline()
	if ok {
		deadlineMs = int64(time.Until(deadline) / time.Millisecond)
	}

	if rt.maxTimeout > 0 && (!ok || rt.maxTimeout < deadlineMs) {
		deadlineMs = rt.maxTimeout
	}

	return deadlineMs
}

// Client builds a new *http.Client from the given *http.Client, wrapping the
// given client's Transport using RoundTripper.
func Client(c *http.Client, opts ...RoundTripperOpt) *http.Client {
	transport := c.Transport
	if transport == nil {
		transport = http.DefaultTransport
	}

	return &http.Client{
		Transport:     RoundTripper(transport, opts...),
		CheckRedirect: c.CheckRedirect,
		Jar:           c.Jar,
		Timeout:       c.Timeout,
	}
}

// RoundTripperOpt is a function which can modify the behaviour of the shed
// client transport middleware.
type RoundTripperOpt func(*roundTripper)

// WithMaxTimeout will set a default X-Client-Timeout-Ms if it is lower than
// any context.Context deadline on the request.
//
// This is intended to be used in cases where some other timeouts are set on
// the client, e.g. ResponseHeaderTimeout.
func WithMaxTimeout(d time.Duration) RoundTripperOpt {
	return func(rt *roundTripper) {
		rt.maxTimeout = int64(d / time.Millisecond)
	}
}

// RoundTripper builds a new http.RoundTripper which propagates context
// deadlines over the network via the `X-Client-Timeout-Ms` request header.
func RoundTripper(n http.RoundTripper, opts ...RoundTripperOpt) http.RoundTripper {
	rt := &roundTripper{next: n}

	for _, opt := range opts {
		opt(rt)
	}

	return rt
}

type propagateMiddleware struct {
	next  http.Handler
	delta func(r *http.Request) time.Duration
}

// ServeHTTP will set the `X-Client-Timeout-Ms` value (adjusted via any
// provided Delta function) as the current requests context deadline.
func (h *propagateMiddleware) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	value, err := strconv.ParseInt(r.Header.Get(Header), 10, 64)
	if err == nil && value > 0 {
		timeout := (time.Duration(value) * time.Millisecond) - h.delta(r)

		ctx, cancel := context.WithTimeout(r.Context(), timeout)
		defer cancel()

		r = r.WithContext(ctx)
	}

	h.next.ServeHTTP(w, r)
}

// PropagateMiddlewareOpt is a function which can modify the behaviour of the shed
// middleware.
type PropagateMiddlewareOpt func(*propagateMiddleware)

// WithDelta allows for adjusting the timeout set by the Middleware, in order
// to account for time spent in the network or on various server queues.
//
// The value returned by this function will by subtracted from the
// `X-Client-Timeout-Ms` value.
func WithDelta(f func(*http.Request) time.Duration) PropagateMiddlewareOpt {
	return func(m *propagateMiddleware) {
		m.delta = f
	}
}

// PropagateMiddleware builds a new http.Handler middleware which sets a context timeout
// on incoming requests if the client has propagated its timeout via the
// `X-Client-Timeout-Ms` header.
func PropagateMiddleware(n http.Handler, opts ...PropagateMiddlewareOpt) http.Handler {
	m := &propagateMiddleware{
		next: n,
		delta: func(_ *http.Request) time.Duration {
			return time.Duration(0)
		},
	}

	for _, opt := range opts {
		opt(m)
	}

	return m
}

type defaultTimeoutMiddleware struct {
	n http.Handler
	f func(*http.Request) time.Duration
}

func (m *defaultTimeoutMiddleware) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if timeout := m.f(r); timeout > time.Duration(0) {
		ctx, cancel := context.WithTimeout(r.Context(), timeout)
		defer cancel()

		r = r.WithContext(ctx)
	}

	m.n.ServeHTTP(w, r)
}

// DefaultTimeoutMiddleware wraps the given handler with a default context
// deadline propagated via the request context.
//
// The timeout function can be used to have dynamic request based upper bounds
// for requests. If this function returns a time.Duration that is not strictly
// greater than 0, no timeout will be set.
func DefaultTimeoutMiddleware(n http.Handler, timeout func(*http.Request) time.Duration) http.Handler {
	return &defaultTimeoutMiddleware{n: n, f: timeout}
}
