defmodule OtpRadio.Station.DistributorTest do
  use ExUnit.Case, async: false

  @station_id "dist_test_#{System.unique_integer([:positive])}"

  setup do
    assert {:ok, _} = OtpRadio.StationManager.create_station(@station_id, "Dist Test")
    on_exit(fn -> OtpRadio.StationManager.stop_station(@station_id) end)
    distributor = OtpRadio.Station.Distributor.via_tuple(@station_id)
    {:ok, distributor: distributor}
  end

  describe "get_buffer/1" do
    test "returns a list (possibly empty)", %{distributor: distributor} do
      buffer = OtpRadio.Station.Distributor.get_buffer(distributor)
      assert is_list(buffer)
    end
  end

  describe "publish/2" do
    test "adds chunk to buffer and get_buffer returns it in chronological order", %{
      distributor: distributor
    } do
      chunk = %{data: <<1, 2, 3>>, sequence: 999, size: 3}
      OtpRadio.Station.Distributor.publish(distributor, chunk)
      buffer = OtpRadio.Station.Distributor.get_buffer(distributor)
      assert length(buffer) >= 1
      last = List.last(buffer)
      assert last.data == chunk.data
      assert last.sequence == chunk.sequence
      assert last.size == chunk.size
    end
  end
end
