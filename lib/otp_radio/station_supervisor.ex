defmodule OtpRadio.StationSupervisor do
  @moduledoc """
  DynamicSupervisor that starts stations on demand (not at app startup).

  No stations are running when the app starts. Stations are added via
  StationManager.create_station/2, which calls DynamicSupervisor.start_child/2
  with a child spec for OtpRadio.Station.Supervisor (one per station).

  Strategy :one_for_one: if one station's supervisor crashes, only that
  station is restarted; other stations are unaffected (fault isolation).
  """

  use DynamicSupervisor

  @doc """
  Starts the dynamic station supervisor. Called from application.ex.
  """
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # one_for_one: each station is independent; crash of one doesn't restart others
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
