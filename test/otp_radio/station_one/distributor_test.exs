defmodule OtpRadio.StationOne.DistributorTest do
  use ExUnit.Case, async: false

  alias OtpRadio.StationOne.Distributor

  describe "get_buffer/0" do
    test "returns a list (possibly empty)" do
      buffer = Distributor.get_buffer()
      assert is_list(buffer)
    end
  end

  describe "publish/1" do
    test "adds chunk to buffer and get_buffer returns it in chronological order" do
      chunk = %{data: <<1, 2, 3>>, sequence: 999, size: 3}
      Distributor.publish(chunk)

      buffer = Distributor.get_buffer()
      assert length(buffer) >= 1
      # Most recent is last in the reversed (chronological) list
      last = List.last(buffer)
      assert last.data == chunk.data
      assert last.sequence == chunk.sequence
      assert last.size == chunk.size
    end
  end
end
