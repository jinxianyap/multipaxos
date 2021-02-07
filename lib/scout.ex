defmodule Scout do

  def start(config, leader, acceptors, pn) do
    config = Configuration.node_id(config, "Scout", pn)
    Debug.starting(config)
    for each <- acceptors do
      send each, {:PREPARE, self(), pn}
    end
    next(leader, acceptors, pn, acceptors, [])
  end

  defp next(leader, acceptors, pn, waitfor, p_values) do
    receive do
      {:PROMISE, a_id, pn_returned, p_accepted} ->
        if Util.compare_pn(pn, pn_returned) == 0 do
          new_p_values = Util.list_union(p_values,p_accepted)
          new_waitfor = List.delete(waitfor, a_id)
          if length(new_waitfor) < length(acceptors) / 2 do
            send leader, {:ADOPTED, pn, new_p_values}
            Process.exit(self(), :kill)
          else
            next(leader, acceptors, pn, new_p_values, new_waitfor)
          end
        else
          send leader, {:PREEMPTED, pn_returned}
          Process.exit(self(), :kill)
        end
    end
  end
end
