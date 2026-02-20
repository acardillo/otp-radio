defmodule OtpRadioWeb.ListenerChannelTest do
  use OtpRadioWeb.ChannelCase, async: false

  # Drains all pushed messages from the mailbox so the next assert_push sees only new messages.
  defp drain_pushes do
    receive do
      %Phoenix.Socket.Message{} -> drain_pushes()
    after
      0 -> :ok
    end
  end

  describe "join listener:one" do
    test "listener joins and receives buffered chunks as pushes", %{} do
      # Publish a chunk so the buffer has something to send
      chunk = %{data: <<1, 2, 3, 4, 5>>, sequence: 0, size: 5}
      OtpRadio.StationOne.Distributor.publish(chunk)

      {:ok, _reply, _socket} =
        OtpRadioWeb.UserSocket
        |> socket("listener_1", %{})
        |> subscribe_and_join(OtpRadioWeb.ListenerChannel, "listener:one")

      # Listener should receive at least one "audio" push (our chunk or from buffer)
      assert_push "audio", %{data: _base64, sequence: _seq, size: _size}
    end

    test "listener count is incremented on join" do
      before = OtpRadio.StationOne.Server.get_status().listener_count

      {:ok, _, _socket} =
        OtpRadioWeb.UserSocket
        |> socket("listener_2", %{})
        |> subscribe_and_join(OtpRadioWeb.ListenerChannel, "listener:one")

      assert OtpRadio.StationOne.Server.get_status().listener_count == before + 1
    end
  end

  describe "live audio" do
    test "listener receives broadcasted audio chunks via push" do
      {:ok, _, _socket} =
        OtpRadioWeb.UserSocket
        |> socket("listener_3", %{})
        |> subscribe_and_join(OtpRadioWeb.ListenerChannel, "listener:one")

      drain_pushes()

      # Broadcast a chunk via PubSub (as Distributor does)
      chunk = %{data: <<99, 100>>, sequence: 42, size: 2}
      Phoenix.PubSub.broadcast(OtpRadio.PubSub, "station:one:audio", {:audio_chunk, chunk})

      assert_push "audio", %{data: "Y2Q=", sequence: 42, size: 2}
    end
  end
end
