defmodule Replica do

  def start(config, server_num, database) do
    config = Configuration.node_id(config, "Replica", server_num)
    Debug.starting(config)
    receive do {:BIND, leaders} -> next(config, server_num, leaders, database, 1, 1, MapSet.new, Map.new, Map.new) end
  end

  defp propose(leaders, slot_in, slot_out, requests, proposals, decisions) do
    window = 3
    if slot_in < slot_out + window and MapSet.size(requests) > 0 do
      c = Enum.at(requests, Util.random(MapSet.size(requests)) - 1)

      if Map.get(decisions, slot_in) == nil do
        new_requests = MapSet.delete(requests, c)
        new_proposals = Map.put(proposals, slot_in, c)
        for each <- leaders do
          send each, {:PROPOSE, slot_in, c}
        end
        propose(leaders, slot_in + 1, slot_out, new_requests, new_proposals, decisions)
      else
        propose(leaders, slot_in + 1, slot_out, requests, proposals, decisions)
      end
    else
      {slot_in, requests, proposals}
    end
  end

  defp perform(database, slot_out, decisions, _command = {client, cid, transactions}) do
    if Enum.find(decisions, fn {s, {client_, cid_, transactions_}} -> s < slot_out and client == client_ and cid == cid_ and transactions == transactions_ end) == nil do
      send database, {:EXECUTE, transactions}
      send client, {:CLIENT_REPLY, cid, true}
      slot_out + 1
    else
      slot_out + 1
    end
  end

  defp allocate(database, slot_out, requests, proposals, decisions) do
    c_decided = Map.get(decisions, slot_out)
    if c_decided != nil do
      c_proposed = Map.get(proposals, slot_out)
      if c_proposed != nil do
        new_proposals = Map.delete(proposals, slot_out)
        new_requests = if c_decided != c_proposed do MapSet.put(requests, c_proposed) else requests end
        new_slot_out = perform(database, slot_out, decisions, c_decided)
        allocate(database, new_slot_out, new_requests, new_proposals, decisions)
      else
        new_slot_out = perform(database, slot_out, decisions, c_decided)
        allocate(database, new_slot_out, requests, proposals, decisions)
      end
    else
      {proposals, requests, slot_out}
    end
  end

  defp next(config, server_num, leaders, database, slot_in, slot_out, requests, proposals, decisions) do
    receive do
      {:CLIENT_REQUEST, c} ->
        send config.monitor, { :CLIENT_REQUEST, server_num }
        {new_slot_in, new_requests, new_proposals} = propose(leaders, slot_in, slot_out, MapSet.put(requests, c), proposals, decisions)
        next(config, server_num, leaders, database, new_slot_in, slot_out, new_requests, new_proposals, decisions)
      {:DECISION, s, c} ->
        new_decisions = Map.put(decisions, s, c)
        {new_proposals, new_requests, new_slot_out} = allocate(database, slot_out, requests, proposals, new_decisions)
        {new_slot_in, new_requests_, new_proposals_} = propose(leaders, slot_in, slot_out, new_requests, new_proposals, new_decisions)
        next(config, server_num, leaders, database, new_slot_in, new_slot_out, new_requests_, new_proposals_, new_decisions)
    end
  end
end
