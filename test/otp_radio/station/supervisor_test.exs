defmodule OtpRadio.Station.SupervisorTest do
  use ExUnit.Case, async: false

  @station_id "sup_test_#{System.unique_integer([:positive])}"

  defp child_pid(children, id) do
    case Enum.find(children, fn {cid, _pid, _t, _m} -> cid == id end) do
      {_id, pid, _type, _modules} when is_pid(pid) -> pid
      _ -> nil
    end
  end

  setup do
    assert {:ok, sup_pid} = OtpRadio.StationManager.create_station(@station_id, "Sup Test")
    on_exit(fn -> OtpRadio.StationManager.stop_station(@station_id) end)
    via = {:via, Registry, {OtpRadio.StationRegistry, {:station_supervisor, @station_id}}}
    {:ok, sup_pid: sup_pid, via: via}
  end

  describe "Station.Supervisor rest_for_one" do
    test "when Broadcaster crashes, Server keeps same PID and Broadcaster and Distributor are restarted",
         %{sup_pid: sup_pid} do
      children = Supervisor.which_children(sup_pid)
      server_pid = child_pid(children, OtpRadio.Station.Server)
      broadcaster_pid = child_pid(children, OtpRadio.Station.Broadcaster)
      distributor_pid = child_pid(children, OtpRadio.Station.Distributor)
      assert is_pid(server_pid) and is_pid(broadcaster_pid) and is_pid(distributor_pid)

      ref = Process.monitor(broadcaster_pid)
      Process.exit(broadcaster_pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^broadcaster_pid, _reason}

      {^server_pid, new_broadcaster_pid, new_distributor_pid} =
        wait_for_restart(sup_pid, server_pid, broadcaster_pid, distributor_pid, 50)

      assert new_broadcaster_pid != broadcaster_pid
      assert new_distributor_pid != distributor_pid
      assert Process.alive?(new_broadcaster_pid)
      assert Process.alive?(new_distributor_pid)
    end
  end

  defp wait_for_restart(_sup_pid, _server_pid, _old_bc, _old_dist, 0) do
    flunk("supervisor did not restart in time")
  end

  defp wait_for_restart(sup_pid, server_pid, old_broadcaster_pid, old_distributor_pid, n) do
    _ = :sys.get_state(sup_pid)
    children = Supervisor.which_children(sup_pid)
    new_server = child_pid(children, OtpRadio.Station.Server)
    new_broadcaster = child_pid(children, OtpRadio.Station.Broadcaster)
    new_distributor = child_pid(children, OtpRadio.Station.Distributor)

    if new_server == server_pid &&
         is_pid(new_broadcaster) &&
         is_pid(new_distributor) &&
         new_broadcaster != old_broadcaster_pid &&
         new_distributor != old_distributor_pid do
      {new_server, new_broadcaster, new_distributor}
    else
      wait_for_restart(sup_pid, server_pid, old_broadcaster_pid, old_distributor_pid, n - 1)
    end
  end
end
