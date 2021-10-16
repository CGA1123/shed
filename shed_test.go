package shed_test

import (
	"bytes"
	"context"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/CGA1123/shed"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type roundTripper func(r *http.Request) (*http.Response, error)

func (rt roundTripper) RoundTrip(r *http.Request) (*http.Response, error) {
	return rt(r)
}

func Test_Client(t *testing.T) {
	t.Parallel()

	t.Run("when request context had a deadline", func(t *testing.T) {
		t.Parallel()

		c := shed.RoundTripper(roundTripper(func(r *http.Request) (*http.Response, error) {
			assert.NotEmpty(t, r.Header.Get(shed.Header))
			assert.Equal(t, r.Header.Get(shed.Header), "9999") // this is brittle

			resp := "ok\n"
			return &http.Response{
				Status:        "200 OK",
				StatusCode:    200,
				Proto:         "HTTP/1.1",
				ProtoMajor:    1,
				ProtoMinor:    1,
				Body:          ioutil.NopCloser(bytes.NewBufferString(resp)),
				ContentLength: int64(len(resp)),
				Request:       r,
				Header:        make(http.Header),
			}, nil
		}))

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		r, err := http.NewRequestWithContext(ctx, "GET", "/foo", nil)
		require.NoError(t, err)

		res, err := c.RoundTrip(r)
		require.NoError(t, err)
		require.NoError(t, res.Body.Close())
	})

	t.Run("when request context does not have a deadline", func(t *testing.T) {
		t.Parallel()

		c := shed.RoundTripper(roundTripper(func(r *http.Request) (*http.Response, error) {
			assert.Empty(t, r.Header.Get(shed.Header))

			resp := "ok\n"
			return &http.Response{
				Status:        "200 OK",
				StatusCode:    200,
				Proto:         "HTTP/1.1",
				ProtoMajor:    1,
				ProtoMinor:    1,
				Body:          ioutil.NopCloser(bytes.NewBufferString(resp)),
				ContentLength: int64(len(resp)),
				Request:       r,
				Header:        make(http.Header),
			}, nil
		}))

		r, err := http.NewRequestWithContext(context.Background(), "GET", "/foo", nil)
		require.NoError(t, err)

		res, err := c.RoundTrip(r)
		require.NoError(t, err)
		require.NoError(t, res.Body.Close())
	})
}

func Test_PropagateMiddleware(t *testing.T) {
	t.Parallel()

	t.Run("when request has a declared timeout", func(t *testing.T) {
		t.Parallel()

		m := shed.PropagateMiddleware(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
			deadline, ok := r.Context().Deadline()

			assert.True(t, ok)
			assert.WithinDuration(t, time.Now().Add(10*time.Second), deadline, time.Millisecond)
		}))

		r, err := http.NewRequestWithContext(context.Background(), "GET", "/foo", nil)
		require.NoError(t, err)
		r.Header.Add(shed.Header, "10000")

		m.ServeHTTP(httptest.NewRecorder(), r)
	})

	t.Run("when request does not have a deadline", func(t *testing.T) {
		t.Parallel()

		m := shed.PropagateMiddleware(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
			_, ok := r.Context().Deadline()

			assert.False(t, ok)
		}))

		r, err := http.NewRequestWithContext(context.Background(), "GET", "/foo", nil)
		require.NoError(t, err)

		m.ServeHTTP(httptest.NewRecorder(), r)
	})
}

func Test_DefaultTimeoutMiddleware(t *testing.T) {
	t.Parallel()

	tcs := []struct {
		d               time.Duration
		timeoutExpected bool
	}{
		{d: time.Duration(0), timeoutExpected: false},
		{d: time.Duration(-1), timeoutExpected: false},
		{d: time.Duration(1000), timeoutExpected: true},
	}
	for _, tc := range tcs {
		handler := http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
			deadline, ok := r.Context().Deadline()

			if tc.timeoutExpected {
				assert.True(t, ok)
				assert.WithinDuration(t, time.Now().Add(tc.d), deadline, time.Millisecond)
			} else {
				assert.False(t, ok)
			}
		})

		timeout := func(_ *http.Request) time.Duration {
			return tc.d
		}

		m := shed.DefaultTimeoutMiddleware(handler, timeout)

		r, err := http.NewRequestWithContext(context.Background(), "GET", "/foo", nil)
		require.NoError(t, err)

		m.ServeHTTP(httptest.NewRecorder(), r)
	}
}
