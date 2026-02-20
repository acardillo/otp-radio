defmodule OtpRadioWeb.BroadcasterChannelTest do
  use OtpRadioWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      OtpRadioWeb.UserSocket
      |> socket("broadcaster_1", %{})
      |> subscribe_and_join(OtpRadioWeb.BroadcasterChannel, "broadcaster:one")

    %{socket: socket}
  end

  describe "join broadcaster:*" do
    test "broadcaster can join with any station id", %{socket: _socket} do
      {:ok, _, _} =
        OtpRadioWeb.UserSocket
        |> socket("broadcaster_2", %{})
        |> subscribe_and_join(OtpRadioWeb.BroadcasterChannel, "broadcaster:two")

      assert true
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
end
