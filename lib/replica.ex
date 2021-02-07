defmodule Replica do

  def start(config, server_num, database) do
    config = Configuration.node_id(config, "Replica", server_num)
    Debug.starting(config)
    receive do {:bind, leaders} -> next(leaders, database, 1, 1, [], [], []) end
  end

  defp next(leaders, state, slot_in, slot_out, requests, proposals, decisions) do
    receive do
      {:request, }
    end
  end
end
