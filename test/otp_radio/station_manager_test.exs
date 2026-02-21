defmodule OtpRadio.StationManagerTest do
  use ExUnit.Case, async: false

  describe "create_station/2" do
    test "starts a station and list_stations includes it" do
      station_id = "test_station_#{System.unique_integer([:positive])}"
      assert {:ok, _pid} = OtpRadio.StationManager.create_station(station_id, "Test Station")
      stations = OtpRadio.StationManager.list_stations()
      found = Enum.find(stations, fn s -> s.id == station_id end)
      assert found != nil
      assert found.name == "Test Station"
      assert is_integer(found.listener_count)
      OtpRadio.StationManager.stop_station(station_id)
    end

    test "create_station with same id returns already_started" do
      id = "dup_#{System.unique_integer([:positive])}"
      assert {:ok, _} = OtpRadio.StationManager.create_station(id, "First")

      assert {:error, {:already_started, _}} =
               OtpRadio.StationManager.create_station(id, "Second")

      OtpRadio.StationManager.stop_station(id)
    end
  end

  describe "stop_station/1" do
    test "stops station and get_station returns not_found" do
      id = "stop_#{System.unique_integer([:positive])}"
      assert {:ok, sup_pid} = OtpRadio.StationManager.create_station(id, "To Stop")
      ref = Process.monitor(sup_pid)
      assert :ok = OtpRadio.StationManager.stop_station(id)
      assert_receive {:DOWN, ^ref, :process, ^sup_pid, _reason}
      assert {:error, :not_found} = OtpRadio.StationManager.get_station(id)
    end
  end

  describe "list_stations/0" do
    test "initially can be empty or have other stations" do
      stations = OtpRadio.StationManager.list_stations()
      assert is_list(stations)
    end
  end

  describe "get_station/1" do
    test "returns {:ok, pid} for existing station" do
      station_id = "get_station_#{System.unique_integer([:positive])}"
      assert {:ok, _} = OtpRadio.StationManager.create_station(station_id, "Test")
      assert {:ok, pid} = OtpRadio.StationManager.get_station(station_id)
      assert is_pid(pid)
      OtpRadio.StationManager.stop_station(station_id)
    end

    test "returns {:error, :not_found} for missing station" do
      assert {:error, :not_found} =
               OtpRadio.StationManager.get_station("nonexistent_#{System.unique_integer()}")
    end
  end
end
