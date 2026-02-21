defmodule OtpRadio.Station.Broadcaster do
  @moduledoc """
  GenServer that manages the broadcaster connection and audio ingestion for one station.

  Parameterized by `station_id`. Receives audio chunks from the broadcaster client,
  validates them, adds sequence numbers, and forwards to this station's Distributor.
  Registered via Registry so the channel can find it by station_id.
  """

  use GenServer
  require Logger

  @max_chunk_size 100_000
  @min_chunk_size 100

  # Client API

  @doc """
  Starts the broadcaster for the given station_id.

  ## Options
    * `:station_id` (required) - Station this broadcaster belongs to
  """
  def start_link(opts) do
    station_id = Keyword.fetch!(opts, :station_id)
    via = via_tuple(station_id)
    GenServer.start_link(__MODULE__, %{station_id: station_id}, name: via)
  end

  @doc """
  Returns the via_tuple for this station's Broadcaster (for Registry lookup).
  """
  def via_tuple(station_id) do
    {:via, Registry, {OtpRadio.StationRegistry, {:station_broadcaster, station_id}}}
  end

  @doc """
  Ingests an audio chunk from the broadcaster. Forwards to this station's Distributor.
  """
  def ingest_chunk(broadcaster, chunk) do
    GenServer.cast(broadcaster, {:ingest_chunk, chunk})
  end

  @doc """
  Resets the sequence to 0 and clears the distributor buffer (new stream).
  """
  def reset_sequence(broadcaster) do
    GenServer.cast(broadcaster, :reset_sequence)
  end

  # Server callbacks

  @impl true
  def init(initial) do
    state = %{
      station_id: initial.station_id,
      connected: false,
      sequence: 0
    }

    Logger.info("Station.Broadcaster started for station_id=#{state.station_id}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:ingest_chunk, chunk}, state) do
    chunk_size = byte_size(chunk)

    cond do
      chunk_size > @max_chunk_size ->
        Logger.warning(
          "Chunk too large (#{chunk_size} bytes), dropping [station_id=#{state.station_id}]"
        )

        {:noreply, state}

      chunk_size < @min_chunk_size ->
        Logger.warning(
          "Chunk too small (#{chunk_size} bytes), dropping [station_id=#{state.station_id}]"
        )

        {:noreply, state}

      true ->
        chunk_with_seq = %{
          data: chunk,
          sequence: state.sequence,
          size: chunk_size
        }

        OtpRadio.Station.Distributor.publish(
          OtpRadio.Station.Distributor.via_tuple(state.station_id),
          chunk_with_seq
        )

        {:noreply, %{state | sequence: state.sequence + 1, connected: true}}
    end
  end

  @impl true
  def handle_cast(:reset_sequence, state) do
    OtpRadio.Station.Distributor.clear_buffer(
      OtpRadio.Station.Distributor.via_tuple(state.station_id)
    )

    {:noreply, %{state | sequence: 0}}
  end
end
