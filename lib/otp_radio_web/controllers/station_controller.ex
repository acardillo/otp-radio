defmodule OtpRadioWeb.StationController do
  @moduledoc """
  API controller for station list (used by listener UI to populate station dropdown).
  """

  use OtpRadioWeb, :controller

  def index(conn, _params) do
    stations = OtpRadio.StationManager.list_stations()
    json(conn, OtpRadioWeb.StationJSON.index(%{stations: stations}))
  end
end
