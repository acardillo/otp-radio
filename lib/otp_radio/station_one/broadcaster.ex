defmodule OtpRadio.StationOne.Broadcaster do
  @moduledoc """
  GenServer that manages the broadcaster connection and audio ingestion.

  This server receives audio chunks from the broadcaster client,
  validates them, adds sequence numbers, and forwards them to the
  Distributor for publishing to listeners.
  """

  use GenServer
  require Logger

  @max_chunk_size 100_000
  @min_chunk_size 100

  # Client API

  @doc """
  Starts the broadcaster server as a named process.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Ingests an audio chunk from the broadcaster.

  The chunk is validated for size, then forwarded to the Distributor
  with a sequence number attached.

  ## Parameters

    - chunk: Binary audio data from the broadcaster
  """
  def ingest_chunk(chunk) do
    GenServer.cast(__MODULE__, {:ingest_chunk, chunk})
  end

  @doc """
  Resets the sequence number to 0.

  Called when the broadcaster (re)joins the channel so the first chunk
  of a new stream is sequence 0 and can be used as the WebM init segment.
  """
  def reset_sequence do
    GenServer.cast(__MODULE__, :reset_sequence)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    state = %{
      connected: false,
      sequence: 0
    }

    Logger.info("StationOne.Broadcaster started")
    {:ok, state}
  end

  @impl true
  def handle_cast({:ingest_chunk, chunk}, state) do
    chunk_size = byte_size(chunk)

    cond do
      chunk_size > @max_chunk_size ->
        Logger.warning("Chunk too large (#{chunk_size} bytes), dropping")
        {:noreply, state}

      chunk_size < @min_chunk_size ->
        Logger.warning("Chunk too small (#{chunk_size} bytes), dropping")
        {:noreply, state}

      true ->
        # Valid chunk - add sequence number and forward
        chunk_with_seq = %{
          data: chunk,
          sequence: state.sequence,
          size: chunk_size
        }

        OtpRadio.StationOne.Distributor.publish(chunk_with_seq)

        {:noreply, %{state | sequence: state.sequence + 1, connected: true}}
    end
  end

  @impl true
  def handle_cast(:reset_sequence, state) do
    {:noreply, %{state | sequence: 0}}
  end
end
