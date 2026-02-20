defmodule OtpRadio.StationOne.BroadcasterTest do
  use ExUnit.Case, async: false

  alias OtpRadio.StationOne.Broadcaster
  alias OtpRadio.StationOne.Distributor

  # Valid chunk size range: 100..100_000 bytes
  @min_valid 100
  @max_valid 100_000

  describe "ingest_chunk/1" do
    test "valid chunk is forwarded to Distributor and appears in buffer" do
      chunk = :binary.copy(<<0>>, @min_valid)
      Broadcaster.ingest_chunk(chunk)

      _ = :sys.get_state(OtpRadio.StationOne.Broadcaster)
      _ = :sys.get_state(OtpRadio.StationOne.Distributor)

      buffer = Distributor.get_buffer()
      assert length(buffer) >= 1

      assert Enum.any?(buffer, fn c -> c.data == chunk and c.size == @min_valid end),
             "expected our chunk in buffer"

      assert Enum.any?(buffer, fn c -> is_integer(c.sequence) end)
    end

    test "chunk smaller than min size is dropped" do
      tiny_chunk = :binary.copy(<<0>>, @min_valid - 1)
      Broadcaster.ingest_chunk(tiny_chunk)

      valid_chunk = :binary.copy(<<1>>, @min_valid)
      Broadcaster.ingest_chunk(valid_chunk)

      _ = :sys.get_state(OtpRadio.StationOne.Broadcaster)
      _ = :sys.get_state(OtpRadio.StationOne.Distributor)

      buffer = Distributor.get_buffer()

      assert Enum.any?(buffer, fn c -> c.data == valid_chunk end),
             "valid chunk should be in buffer"

      refute Enum.any?(buffer, fn c -> c.data == tiny_chunk end), "tiny chunk should be dropped"
    end

    test "chunk larger than max size is dropped" do
      huge_chunk = :binary.copy(<<0>>, @max_valid + 1)
      Broadcaster.ingest_chunk(huge_chunk)

      valid_chunk = :binary.copy(<<2>>, @min_valid)
      Broadcaster.ingest_chunk(valid_chunk)

      _ = :sys.get_state(OtpRadio.StationOne.Broadcaster)
      _ = :sys.get_state(OtpRadio.StationOne.Distributor)

      buffer = Distributor.get_buffer()

      assert Enum.any?(buffer, fn c -> c.data == valid_chunk end),
             "valid chunk should be in buffer"

      refute Enum.any?(buffer, fn c -> c.data == huge_chunk end), "huge chunk should be dropped"
    end
  end
end
