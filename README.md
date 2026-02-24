# OTP Radio

[![CI](https://github.com/acardillo/otp-radio/actions/workflows/ci.yml/badge.svg)](https://github.com/acardillo/otp-radio/actions/workflows/ci.yml)

Real-time audio streaming. One or more stations; each station has a single broadcaster and zero or more listeners. Web clients send and receive Opus chunks over Phoenix channels.

## Prerequisites

- Elixir 1.14+
- Phoenix 1.7

## Quick start

```bash
mix setup
mix phx.server
```

- **Broadcaster:** [http://localhost:4000/broadcaster.html](http://localhost:4000/broadcaster.html) — pick a station, start streaming from the mic.
- **Listener:** [http://localhost:4000/listener.html](http://localhost:4000/listener.html) — pick a station, connect to hear the stream.

Stations are created at boot via `StationBootstrap` (default: four stations). The list is exposed at `GET /api/stations` and used by both UIs.

## Development

```bash
mix test
mix precommit
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the OTP and channel layout works.
