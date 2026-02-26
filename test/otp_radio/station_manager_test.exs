defmodule OtpRadio.StationManagerTest do
  use ExUnit.Case, async: false

  describe "create_station/0" do
    test "returns {:ok, station_id} with a string id" do
      assert {:ok, station_id} = OtpRadio.StationManager.create_station()
      assert is_binary(station_id)
      OtpRadio.StationManager.stop_station(station_id)
    end

    test "starts a station and list_stations includes it" do
      assert {:ok, station_id} = OtpRadio.StationManager.create_station()
      stations = OtpRadio.StationManager.list_stations()
      found = Enum.find(stations, fn s -> s.id == station_id end)
      assert found != nil
      assert found.name == station_id
      assert is_integer(found.listener_count)
      OtpRadio.StationManager.stop_station(station_id)
    end

    test "each call returns a different id" do
      assert {:ok, id1} = OtpRadio.StationManager.create_station()
      assert {:ok, id2} = OtpRadio.StationManager.create_station()
      assert id1 != id2
      OtpRadio.StationManager.stop_station(id1)
      OtpRadio.StationManager.stop_station(id2)
    end
  end

  describe "stop_station/1" do
    test "returns {:error, :invalid_args} for non-binary station_id" do
      assert {:error, :invalid_args} = OtpRadio.StationManager.stop_station(123)
      assert {:error, :invalid_args} = OtpRadio.StationManager.stop_station(nil)
    end

    test "stops station and get_station returns not_found" do
      assert {:ok, station_id} = OtpRadio.StationManager.create_station()

      [{sup_pid, _}] =
        Registry.lookup(OtpRadio.StationRegistry, {:station_supervisor, station_id})

      ref = Process.monitor(sup_pid)
      assert :ok = OtpRadio.StationManager.stop_station(station_id)
      assert_receive {:DOWN, ^ref, :process, ^sup_pid, _reason}
      # Allow Registry to process DOWN and remove keys
      _ = :sys.get_state(Process.whereis(OtpRadio.StationRegistry))
      assert {:error, :not_found} = OtpRadio.StationManager.get_station(station_id)
    end
  end

  describe "list_stations/0" do
    test "returns a list (possibly empty or with default stations)" do
      stations = OtpRadio.StationManager.list_stations()
      assert is_list(stations)
    end
  end

  describe "get_station/1" do
    test "returns {:ok, pid} for existing station" do
      assert {:ok, station_id} = OtpRadio.StationManager.create_station()
      assert {:ok, pid} = OtpRadio.StationManager.get_station(station_id)
      assert is_pid(pid)
      OtpRadio.StationManager.stop_station(station_id)
    end

    test "returns {:error, :not_found} for missing station" do
      assert {:error, :not_found} =
               OtpRadio.StationManager.get_station("nonexistent_#{System.unique_integer()}")
    end

    test "returns {:error, :invalid_args} for non-binary station_id" do
      assert {:error, :invalid_args} = OtpRadio.StationManager.get_station(123)
      assert {:error, :invalid_args} = OtpRadio.StationManager.get_station(nil)
    end
  end
end
