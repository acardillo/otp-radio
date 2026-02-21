defmodule OtpRadioWeb.BroadcasterChannelTest do
  use OtpRadioWeb.ChannelCase, async: false

  @station_id "broadcaster_channel_test_#{System.unique_integer([:positive])}"

  setup do
    assert {:ok, _} = OtpRadio.StationManager.create_station(@station_id, "Broadcaster Test")
    on_exit(fn -> OtpRadio.StationManager.stop_station(@station_id) end)

    {:ok, _, socket} =
      OtpRadioWeb.UserSocket
      |> socket("broadcaster_1", %{})
      |> subscribe_and_join(OtpRadioWeb.BroadcasterChannel, "broadcaster:#{@station_id}")

    %{socket: socket}
  end

  describe "join broadcaster:*" do
    test "broadcaster can join when station exists", %{socket: _socket} do
      # already joined in setup
      assert true
    end

    test "broadcaster join rejected when station does not exist" do
      {:error, %{reason: "station not found"}} =
        OtpRadioWeb.UserSocket
        |> socket("broadcaster_2", %{})
        |> subscribe_and_join(OtpRadioWeb.BroadcasterChannel, "broadcaster:nonexistent")
    end
  end

  describe "handle_in audio_chunk" do
    test "valid base64 data replies :ok", %{socket: socket} do
      payload = %{"data" => Base.encode64(<<0, 1, 2>>)}
      ref = push(socket, "audio_chunk", payload)
      assert_reply ref, :ok
    end

    test "invalid payload (no data field) replies error", %{socket: socket} do
      ref = push(socket, "audio_chunk", %{})
      assert_reply ref, :error, %{reason: "invalid data"}
    end
  end

  describe "handle_in listener_count" do
    test "replies with current listener count from server", %{socket: socket} do
      server = OtpRadio.Station.Server.via_tuple(@station_id)
      expected = OtpRadio.Station.Server.get_status(server).listener_count
      ref = push(socket, "listener_count", %{})
      assert_reply ref, :ok, %{count: ^expected}
    end
  end
end
