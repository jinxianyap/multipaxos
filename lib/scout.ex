defmodule Scout do

  def start(config, leader, acceptors, pn, server_num) do
    config = Configuration.node_id(config, "Scout", pn)
    # Debug.starting(config)
    send config.monitor, {:SCOUT_SPAWNED, server_num}
    for each <- acceptors do
      send each, {:PREPARE, self(), pn}
    end
    next(config, leader, acceptors, pn, acceptors, [], server_num)
  end

  defp next(config, leader, acceptors, pn, waitfor, p_values, server_num) do
    receive do
      {:PROMISE, a_id, pn_returned, p_accepted} ->
        if Util.compare_pn(pn, pn_returned) == 0 do
          # IO.puts("p_values: #{inspect p_values}")
          # IO.puts("p_accepted: #{inspect p_accepted}")
          new_p_values = List.flatten(Enum.map(p_accepted, fn accepted -> Util.list_union(p_values,accepted) end))
          # IO.puts "PROMISE new_p_values: #{inspect new_p_values}"
          new_waitfor = List.delete(waitfor, a_id)
          if length(new_waitfor) < length(acceptors) / 2 do
            send leader, {:ADOPTED, pn, new_p_values}
            send config.monitor, {:SCOUT_FINISHED, server_num}
            Process.exit(self(), :kill)
          else
            next(config, leader, acceptors, pn, new_waitfor, new_p_values, server_num)
          end
        else
          send leader, {:PREEMPTED, pn_returned}
          send config.monitor, {:SCOUT_FINISHED, server_num}
          Process.exit(self(), :kill)
        end
    end
  end
end
