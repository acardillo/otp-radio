defmodule OtpRadio.StationOne.Server do
  @moduledoc """
  GenServer that manages Station One's state and metadata.

  This server is the single source of truth for the station's name,
  listener count, and broadcast status. It runs continuously as part
  of the station supervision tree.
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the station server as a named process.

  The server is registered under the module name for easy access.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Returns the current station state.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Increments the listener count by 1.

  This should be called when a listener connects to the station.
  """
  def increment_listeners do
    GenServer.cast(__MODULE__, :increment_listeners)
  end

  @doc """
  Decrements the listener count by 1.

  This should be called when a listener disconnects from the station.
  """
  def decrement_listeners do
    GenServer.cast(__MODULE__, :decrement_listeners)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    state = %{
      name: "Station One",
      status: :idle,
      listener_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info("StationOne.Server started")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:increment_listeners, state) do
    {:noreply, %{state | listener_count: state.listener_count + 1}}
  end

  @impl true
  def handle_cast(:decrement_listeners, state) do
    {:noreply, %{state | listener_count: state.listener_count - 1}}
  end
end
