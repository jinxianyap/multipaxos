defmodule Scout do

  def start(config, leader, acceptors, pn) do
    config = Configuration.node_id(config, "Scout", pn)
    Debug.starting(config)
    for each <- acceptors do
      send each, {:prepare, self(), pn}
    end
    next(leader, acceptors, pn, acceptors, [])
  end

  defp next(leader, acceptors, pn, waitfor, p_values) do
    receive do
      {:promise, a_id, pn_returned, p_accepted} ->
        if pn == pn_returned do
          new_p_values = p_values ++ p_accepted
          new_waitfor = List.delete(waitfor, a_id)
          if length(new_waitfor) < length(acceptors) / 2 do
            send leader, {:adopted, pn, new_p_values}
            Process.exit(self(), :normal)
          else
            next(leader, acceptors, pn, new_p_values, new_waitfor)
          end
        else
          send leader, {:preempted, pn_returned}
          Process.exit(self(), :normal)
        end
    end
  end
end
