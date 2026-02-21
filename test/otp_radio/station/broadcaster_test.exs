defmodule OtpRadio.Station.BroadcasterTest do
  use ExUnit.Case, async: false

  @station_id "bc_test_#{System.unique_integer([:positive])}"
  @min_valid 100
  @max_valid 100_000

  setup do
    assert {:ok, _} = OtpRadio.StationManager.create_station(@station_id, "BC Test")
    on_exit(fn -> OtpRadio.StationManager.stop_station(@station_id) end)
    broadcaster = OtpRadio.Station.Broadcaster.via_tuple(@station_id)
    distributor = OtpRadio.Station.Distributor.via_tuple(@station_id)
    {:ok, broadcaster: broadcaster, distributor: distributor}
  end

  describe "ingest_chunk/2" do
    test "valid chunk is forwarded to Distributor and appears in buffer", %{
      broadcaster: broadcaster,
      distributor: distributor
    } do
      chunk = :binary.copy(<<0>>, @min_valid)
      OtpRadio.Station.Broadcaster.ingest_chunk(broadcaster, chunk)
      _ = :sys.get_state(broadcaster)
      buffer = OtpRadio.Station.Distributor.get_buffer(distributor)
      assert length(buffer) >= 1
      assert Enum.any?(buffer, fn c -> c.data == chunk and c.size == @min_valid end)
    end

    test "chunk smaller than min size is dropped", %{
      broadcaster: broadcaster,
      distributor: distributor
    } do
      tiny = :binary.copy(<<0>>, @min_valid - 1)
      OtpRadio.Station.Broadcaster.ingest_chunk(broadcaster, tiny)
      valid = :binary.copy(<<1>>, @min_valid)
      OtpRadio.Station.Broadcaster.ingest_chunk(broadcaster, valid)
      _ = :sys.get_state(broadcaster)
      _ = :sys.get_state(distributor)
      buffer = OtpRadio.Station.Distributor.get_buffer(distributor)
      assert Enum.any?(buffer, fn c -> c.data == valid end)
      refute Enum.any?(buffer, fn c -> c.data == tiny end)
    end

    test "chunk larger than max size is dropped", %{
      broadcaster: broadcaster,
      distributor: distributor
    } do
      huge = :binary.copy(<<0>>, @max_valid + 1)
      OtpRadio.Station.Broadcaster.ingest_chunk(broadcaster, huge)
      valid = :binary.copy(<<2>>, @min_valid)
      OtpRadio.Station.Broadcaster.ingest_chunk(broadcaster, valid)
      _ = :sys.get_state(broadcaster)
      _ = :sys.get_state(distributor)
      buffer = OtpRadio.Station.Distributor.get_buffer(distributor)
      assert Enum.any?(buffer, fn c -> c.data == valid end)
      refute Enum.any?(buffer, fn c -> c.data == huge end)
    end
  end
end
