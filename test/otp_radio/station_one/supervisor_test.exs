defmodule OtpRadio.StationOne.SupervisorTest do
  use ExUnit.Case, async: false

  defp child_pid(children, id) do
    case Enum.find(children, fn {cid, _pid, _t, _m} -> cid == id end) do
      {_id, pid, _type, _modules} when is_pid(pid) -> pid
      _ -> nil
    end
  end

  defp pids_by_module(children) do
    %{
      server: child_pid(children, OtpRadio.StationOne.Server),
      broadcaster: child_pid(children, OtpRadio.StationOne.Broadcaster),
      distributor: child_pid(children, OtpRadio.StationOne.Distributor)
    }
  end

  describe "StationOne.Supervisor" do
    test "supervisor is running and has Server, Broadcaster, Distributor as children" do
      pid = Process.whereis(OtpRadio.StationOne.Supervisor)
      assert is_pid(pid)
      assert Process.alive?(pid)

      children = Supervisor.which_children(OtpRadio.StationOne.Supervisor)
      child_ids = Enum.map(children, fn {id, _pid, _type, _modules} -> id end)

      assert OtpRadio.StationOne.Server in child_ids
      assert OtpRadio.StationOne.Broadcaster in child_ids
      assert OtpRadio.StationOne.Distributor in child_ids
    end

    test "rest_for_one: when Broadcaster crashes, Server keeps same PID and Broadcaster and Distributor are restarted" do
      children = Supervisor.which_children(OtpRadio.StationOne.Supervisor)
      pids = pids_by_module(children)

      server_pid = pids.server
      broadcaster_pid = pids.broadcaster
      distributor_pid = pids.distributor

      assert is_pid(server_pid) and is_pid(broadcaster_pid) and is_pid(distributor_pid)

      ref = Process.monitor(broadcaster_pid)
      Process.exit(broadcaster_pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^broadcaster_pid, _reason}

      # Let the supervisor finish restarting (rest_for_one: Broadcaster then Distributor)
      {^server_pid, new_broadcaster_pid, new_distributor_pid} =
        wait_for_restart(server_pid, broadcaster_pid, distributor_pid, 50)

      assert new_broadcaster_pid != broadcaster_pid
      assert new_distributor_pid != distributor_pid
      assert Process.alive?(new_broadcaster_pid)
      assert Process.alive?(new_distributor_pid)
    end
  end

  defp wait_for_restart(_server_pid, _old_broadcaster_pid, _old_distributor_pid, 0) do
    flunk("supervisor did not restart Broadcaster and Distributor in time")
  end

  defp wait_for_restart(server_pid, old_broadcaster_pid, old_distributor_pid, n) do
    _ = :sys.get_state(OtpRadio.StationOne.Supervisor)

    children = Supervisor.which_children(OtpRadio.StationOne.Supervisor)
    pids = pids_by_module(children)

    new_server = pids.server
    new_broadcaster = pids.broadcaster
    new_distributor = pids.distributor

    if new_server == server_pid &&
         is_pid(new_broadcaster) &&
         is_pid(new_distributor) &&
         new_broadcaster != old_broadcaster_pid &&
         new_distributor != old_distributor_pid do
      {new_server, new_broadcaster, new_distributor}
    else
      wait_for_restart(server_pid, old_broadcaster_pid, old_distributor_pid, n - 1)
    end
  end
end
