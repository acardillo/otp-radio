defmodule OtpRadio.StationBootstrap do
  @moduledoc """
  Creates the initial set of stations at application startup.
  Called once from Application.start/2 after the supervision tree is running.
  """

  @stations [
    {"one", "Station One"},
    {"two", "Station Two"},
    {"three", "Station Three"},
    {"four", "Station Four"}
  ]

  @doc """
  Creates 4 prebaked stations. Safe to call once at startup.
  """
  def bootstrap do
    for {id, name} <- @stations do
      case OtpRadio.StationManager.create_station(id, name) do
        {:ok, _pid} -> :ok
        {:error, _} -> :ok
      end
    end
  end
end
