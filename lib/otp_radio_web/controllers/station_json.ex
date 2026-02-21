defmodule OtpRadioWeb.StationJSON do
  @moduledoc """
  Renders station list for API (GET /api/stations).
  """

  def index(%{stations: stations}) do
    Enum.map(stations, &station/1)
  end

  defp station(s) do
    %{
      id: s.id,
      name: s.name,
      listener_count: s.listener_count
    }
  end
end
