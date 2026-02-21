defmodule OtpRadio.Station.ServerTest do
  use ExUnit.Case, async: false

  @station_id "server_test_#{System.unique_integer([:positive])}"

  setup do
    assert {:ok, _} = OtpRadio.StationManager.create_station(@station_id, "Server Test Station")
    on_exit(fn -> OtpRadio.StationManager.stop_station(@station_id) end)
    {:ok, server: OtpRadio.Station.Server.via_tuple(@station_id)}
  end

  describe "get_status/1" do
    test "returns map with station_id, name, status, listener_count, started_at", %{
      server: server
    } do
      status = OtpRadio.Station.Server.get_status(server)
      assert status.station_id == @station_id
      assert status.name == "Server Test Station"
      assert status.status == :idle
      assert is_integer(status.listener_count) and status.listener_count >= 0
      assert %DateTime{} = status.started_at
    end
  end

  describe "increment_listeners/1 and decrement_listeners/1" do
    test "increment increases listener_count by 1", %{server: server} do
      before = OtpRadio.Station.Server.get_status(server).listener_count
      OtpRadio.Station.Server.increment_listeners(server)
      assert OtpRadio.Station.Server.get_status(server).listener_count == before + 1
    end

    test "decrement decreases listener_count (not below 0)", %{server: server} do
      OtpRadio.Station.Server.increment_listeners(server)
      before = OtpRadio.Station.Server.get_status(server).listener_count
      OtpRadio.Station.Server.decrement_listeners(server)
      assert OtpRadio.Station.Server.get_status(server).listener_count == before - 1
    end
  end
end
