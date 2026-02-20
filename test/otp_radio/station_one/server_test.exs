defmodule OtpRadio.StationOne.ServerTest do
  use ExUnit.Case, async: false

  alias OtpRadio.StationOne.Server

  describe "get_status/0" do
    test "returns a map with name, status, listener_count, and started_at" do
      status = Server.get_status()

      assert is_map(status)
      assert status.name == "Station One"
      assert status.status == :idle
      assert is_integer(status.listener_count) and status.listener_count >= 0
      assert %DateTime{} = status.started_at
    end
  end

  describe "increment_listeners/0" do
    test "increases listener_count by 1" do
      before = Server.get_status().listener_count
      Server.increment_listeners()
      assert Server.get_status().listener_count == before + 1
    end
  end

  describe "decrement_listeners/0" do
    test "decreases listener_count by 1" do
      Server.increment_listeners()
      before = Server.get_status().listener_count
      Server.decrement_listeners()
      assert Server.get_status().listener_count == before - 1
    end
  end
end
