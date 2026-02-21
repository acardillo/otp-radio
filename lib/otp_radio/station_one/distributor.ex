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

  @doc """
  Clears the buffer and init chunk.

  Called when the broadcaster (re)joins so we do not send stale chunks
  from the previous stream. The next chunk (sequence 0) becomes the new init.
  """
  def clear_buffer do
    GenServer.cast(__MODULE__, :clear_buffer)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    state = %{
      buffer: [],
      init_chunk: nil,
      topic: @topic
    }

    Logger.info("StationOne.Distributor started with topic: #{@topic}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:publish, chunk}, state) do
    # Broadcast to all listeners via PubSub
    Phoenix.PubSub.broadcast(OtpRadio.PubSub, @topic, {:audio_chunk, chunk})

    # Store first chunk (sequence 0) as init segment so new listeners get WebM init before media segments
    state = if chunk.sequence == 0, do: %{state | init_chunk: chunk}, else: state

    # Add to circular buffer (keep most recent 50 chunks)
    buffer = [chunk | state.buffer] |> Enum.take(@buffer_size)

    {:noreply, %{state | buffer: buffer}}
  end

  @impl true
  def handle_cast(:clear_buffer, state) do
    {:noreply, %{state | buffer: [], init_chunk: nil}}
  end

  @impl true
  def handle_call(:get_buffer, _from, state) do
    # Return chunks in chronological order (oldest first). Prepend init segment so MSE gets WebM init before any media.
    buffer = Enum.reverse(state.buffer)
    chunks = if state.init_chunk != nil and (buffer == [] or hd(buffer).sequence != 0),
               do: [state.init_chunk | buffer],
               else: buffer
    {:reply, chunks, state}
  end
end
