defmodule OtpRadioWeb.StationControllerTest do
  use OtpRadioWeb.ConnCase, async: false

  describe "GET /api/stations" do
    test "returns 200 and a list of stations with id, name, listener_count", %{conn: conn} do
      conn = get(conn, ~p"/api/stations")
      assert conn.status == 200

      body = json_response(conn, 200)
      assert is_list(body)

      for station <- body do
        assert Map.has_key?(station, "id")
        assert Map.has_key?(station, "name")
        assert Map.has_key?(station, "listener_count")
        assert is_binary(station["id"])
        assert is_binary(station["name"])
        assert is_integer(station["listener_count"])
      end
    end
  end
end
