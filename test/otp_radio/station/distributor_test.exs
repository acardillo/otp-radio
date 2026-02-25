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

    test "sequence 0 is stored as init_chunk and included first in get_buffer", %{
      distributor: distributor
    } do
      init = %{data: <<0>>, sequence: 0, size: 1}
      later = %{data: <<1, 2>>, sequence: 1, size: 2}
      OtpRadio.Station.Distributor.publish(distributor, init)
      OtpRadio.Station.Distributor.publish(distributor, later)
      buffer = OtpRadio.Station.Distributor.get_buffer(distributor)
      assert length(buffer) == 2
      assert hd(buffer).sequence == 0
      assert hd(buffer).data == <<0>>
      assert List.last(buffer).sequence == 1
    end
  end

  describe "clear_buffer/1" do
    test "clears buffer and init_chunk so get_buffer returns empty list", %{
      distributor: distributor
    } do
      init = %{data: <<0>>, sequence: 0, size: 1}
      OtpRadio.Station.Distributor.publish(distributor, init)
      assert length(OtpRadio.Station.Distributor.get_buffer(distributor)) == 1

      OtpRadio.Station.Distributor.clear_buffer(distributor)
      buffer = OtpRadio.Station.Distributor.get_buffer(distributor)
      assert buffer == []
    end
  end
end
