defmodule OtpRadioWeb.ListenerChannelTest do
  use OtpRadioWeb.ChannelCase, async: false

  @station_id "listener_channel_test_#{System.unique_integer([:positive])}"

  defp drain_pushes do
    receive do
      %Phoenix.Socket.Message{} -> drain_pushes()
    after
      0 -> :ok
    end
  end

  setup do
    assert {:ok, _} = OtpRadio.StationManager.create_station(@station_id, "Listener Test")
    on_exit(fn -> OtpRadio.StationManager.stop_station(@station_id) end)
    %{station_id: @station_id}
  end

  describe "join listener:*" do
    test "listener joins and receives buffered chunks as pushes", %{station_id: station_id} do
      distributor = OtpRadio.Station.Distributor.via_tuple(station_id)
      chunk = %{data: <<1, 2, 3, 4, 5>>, sequence: 0, size: 5}
      OtpRadio.Station.Distributor.publish(distributor, chunk)

      {:ok, _reply, _socket} =
        OtpRadioWeb.UserSocket
        |> socket("listener_1", %{})
        |> subscribe_and_join(OtpRadioWeb.ListenerChannel, "listener:#{station_id}")

      assert_push "audio", %{data: _base64, sequence: _seq, size: _size}
    end

    test "listener count is incremented on join", %{station_id: station_id} do
      server = OtpRadio.Station.Server.via_tuple(station_id)
      before = OtpRadio.Station.Server.get_status(server).listener_count

      {:ok, _, _socket} =
        OtpRadioWeb.UserSocket
        |> socket("listener_2", %{})
        |> subscribe_and_join(OtpRadioWeb.ListenerChannel, "listener:#{station_id}")

      assert OtpRadio.Station.Server.get_status(server).listener_count == before + 1
    end

    test "listener join rejected when station does not exist" do
      {:error, %{reason: "station not found"}} =
        OtpRadioWeb.UserSocket
        |> socket("listener_x", %{})
        |> subscribe_and_join(OtpRadioWeb.ListenerChannel, "listener:nonexistent")
    end
  end

  describe "live audio" do
    test "listener receives broadcasted audio chunks via push", %{station_id: station_id} do
      {:ok, _, _socket} =
        OtpRadioWeb.UserSocket
        |> socket("listener_3", %{})
        |> subscribe_and_join(OtpRadioWeb.ListenerChannel, "listener:#{station_id}")

      drain_pushes()

      topic = OtpRadio.Station.Distributor.topic_for_station(station_id)
      chunk = %{data: <<99, 100>>, sequence: 42, size: 2}
      Phoenix.PubSub.broadcast(OtpRadio.PubSub, topic, {:audio_chunk, chunk})

      assert_push "audio", %{data: "Y2Q=", sequence: 42, size: 2}
    end
  end
end
