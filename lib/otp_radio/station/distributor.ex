defmodule OtpRadio.Station.Distributor do
  @moduledoc """
  GenServer that distributes audio chunks to listeners via PubSub for one station.

  Parameterized by `station_id`. Publishes to topic "station:\#{station_id}:audio"
  and keeps a circular buffer for late joiners. Registered via Registry.
  """

  use GenServer
  require Logger

  @buffer_size 50

  # Client API

  @doc """
  Starts the distributor for the given station_id.
  """
  def start_link(opts) do
    station_id = Keyword.fetch!(opts, :station_id)
    via = via_tuple(station_id)
    topic = topic_for_station(station_id)
    GenServer.start_link(__MODULE__, %{station_id: station_id, topic: topic}, name: via)
  end

  @doc """
  Returns the via_tuple for this station's Distributor.
  """
  def via_tuple(station_id) do
    {:via, Registry, {OtpRadio.StationRegistry, {:station_distributor, station_id}}}
  end

  @doc """
  PubSub topic for this station's audio (used by listeners to subscribe).
  """
  def topic_for_station(station_id) do
    "station:#{station_id}:audio"
  end

  @doc """
  Publishes an audio chunk to all listeners of this station.
  """
  def publish(distributor, chunk) do
    GenServer.cast(distributor, {:publish, chunk})
  end

  @doc """
  Returns the current buffer of recent chunks (for late-joiner catch-up).
  """
  def get_buffer(distributor) do
    GenServer.call(distributor, :get_buffer)
  end

  @doc """
  Clears the buffer and init chunk when the broadcaster starts a new stream.
  """
  def clear_buffer(distributor) do
    GenServer.cast(distributor, :clear_buffer)
  end

  # Server callbacks

  @impl true
  def init(initial) do
    state = %{
      station_id: initial.station_id,
      topic: initial.topic,
      buffer: [],
      init_chunk: nil
    }

    Logger.info(
      "Station.Distributor started for station_id=#{state.station_id} topic=#{state.topic}"
    )

    {:ok, state}
  end

  @impl true
  def handle_cast({:publish, chunk}, state) do
    Phoenix.PubSub.broadcast(OtpRadio.PubSub, state.topic, {:audio_chunk, chunk})

    state =
      if chunk.sequence == 0,
        do: %{state | init_chunk: chunk},
        else: state

    buffer = [chunk | state.buffer] |> Enum.take(@buffer_size)
    {:noreply, %{state | buffer: buffer}}
  end

  @impl true
  def handle_cast(:clear_buffer, state) do
    {:noreply, %{state | buffer: [], init_chunk: nil}}
  end

  @impl true
  def handle_call(:get_buffer, _from, state) do
    buffer = Enum.reverse(state.buffer)

    chunks =
      if state.init_chunk != nil and (buffer == [] or hd(buffer).sequence != 0) do
        [state.init_chunk | buffer]
      else
        buffer
      end

    {:reply, chunks, state}
  end
end
