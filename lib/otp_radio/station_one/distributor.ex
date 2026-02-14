defmodule OtpRadio.StationOne.Distributor do
  @moduledoc """
  GenServer that distributes audio chunks to listeners via PubSub.

  This server broadcasts audio chunks to all connected listeners and
  maintains a circular buffer of recent chunks for late joiners. When
  a new listener connects, they receive the buffered chunks first to
  enable smooth playback startup.
  """

  use GenServer
  require Logger

  @topic "station:one:audio"
  @buffer_size 50

  # Client API

  @doc """
  Starts the distributor server as a named process.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Publishes an audio chunk to all listeners.

  The chunk is broadcast via PubSub and added to the circular buffer.

  ## Parameters

    - chunk: Map containing audio data and metadata
  """
  def publish(chunk) do
    GenServer.cast(__MODULE__, {:publish, chunk})
  end

  @doc """
  Returns the current buffer of recent audio chunks.

  Used when a listener joins to catch them up on recent audio.
  """
  def get_buffer do
    GenServer.call(__MODULE__, :get_buffer)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    state = %{
      buffer: [],
      topic: @topic
    }

    Logger.info("StationOne.Distributor started with topic: #{@topic}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:publish, chunk}, state) do
    # Broadcast to all listeners via PubSub
    Phoenix.PubSub.broadcast(OtpRadio.PubSub, @topic, {:audio_chunk, chunk})

    # Add to circular buffer (keep most recent 50 chunks)
    buffer = [chunk | state.buffer] |> Enum.take(@buffer_size)

    {:noreply, %{state | buffer: buffer}}
  end

  @impl true
  def handle_call(:get_buffer, _from, state) do
    # Return chunks in chronological order (oldest first)
    {:reply, Enum.reverse(state.buffer), state}
  end
end
