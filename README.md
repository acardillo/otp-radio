# OTP Radio

[![CI](https://github.com/acardillo/otp-radio/actions/workflows/ci.yml/badge.svg)](https://github.com/acardillo/otp-radio/actions/workflows/ci.yml)

**Audio Livestream with Fault Tolerance** - An Elixir/OTP system for real-time audio broadcasting. Fault-tolerant multi-station architecture using supervision trees, GenServers, and Phoenix PubSub. Web clients send and receive Opus audio chunks over Phoenix Channels, capturing audio using the MediaRecorder API and supporting playback via Media Source Extensions.

## Prerequisites

- Elixir 1.14+
- Phoenix 1.7

## Quick start

```bash
# 1. Install dependencies
mix setup

# 2. Run Server
mix phx.server
iex -S mix phx.server # to call into the running app
```

[localhost:4000/broadcaster.html](http://localhost:4000/broadcaster.html) — pick a station, start streaming from the mic.

[localhost:4000/listener.html](http://localhost:4000/listener.html) — pick a station, connect to hear the stream.

## Development

```bash
# Run tests
mix test

# Compile, format & run tests
mix precommit
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the OTP and channel layout works.
