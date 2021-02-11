defmodule Replica do

  def start(config, server_num, database) do
    config = Configuration.node_id(config, "Replica", server_num)
    Debug.starting(config)
    receive do {:BIND, leaders} -> next(leaders, database, 1, 1, [], [], []) end
  end

  # assuming a reconfig request is in the form { :CLIENT_REQUEST, {cid, sent_index, {:RECONFIG, new_leaders}} }
  defp isreconfig(_command = {name, _leaders}) do
    name == :RECONFIG
  end

  defp propose(leaders, slot_in, slot_out, requests, proposals, decisions) do
    window = 3
    if slot_in < slot_out + window and length(requests) > 0 do
      c = Enum.at(requests, Util.random(length(requests)) - 1)
      
      
      reconfig_req = Enum.find(decisions, fn{s_in, {_, _, op}} -> s_in == slot_in - window && isreconfig(op) end)
      new_leaders = 
        if (reconfig_req != nil) do
          {_, _, {_, new_ls}} = reconfig_req
          new_ls
        else
          leaders
        end
      

      if Enum.find(decisions, fn {s_in, _c} -> s_in == slot_in end) == nil do
        new_requests = List.delete(requests, c)
        new_proposals = Util.list_union(proposals, {slot_in, c})
        for each <- new_leaders do
          send each, {:PROPOSE, slot_in, c}
        end
        propose(new_leaders, slot_in + 1, slot_out, new_requests, new_proposals, decisions)
      else
        propose(new_leaders, slot_in + 1, slot_out, requests, proposals, decisions)
      end
    else
      {slot_in, requests, proposals}
    end
  end

  defp perform(database, slot_out, decisions, _command = {client, cid, transactions}) do
    # reconfigs ignored for now
    if Enum.find(decisions, fn {s, _c} -> s < slot_out end) == nil do
      send database, transactions
      # how to get response from database?
      send client, {:CLIENT_REPLY, cid, true}
      slot_out + 1
    else
      slot_out + 1
    end
  end

  defp allocate(database, slot_out, requests, proposals, decisions) do
    decided = Enum.find(decisions, fn {s, _c} -> s == slot_out end)
    if decided != nil do
      {_, c_decided} = decided
      proposed = Enum.find(proposals, fn {s, _c} -> s == slot_out end)
      if proposed != nil do
        {_, c_proposed} = proposed
        new_proposals = List.delete(proposals, proposed)
        new_requests = if c_decided != c_proposed do requests ++ [c_proposed] else requests end
        new_slot_out = perform(database, slot_out, decisions, c_decided)
        allocate(database, new_slot_out, new_requests, new_proposals, decisions)
      else
        new_slot_out = perform(database, slot_out, decisions, c_decided)
        allocate(database, new_slot_out, requests, proposals, decisions)
      end
    else
      {proposals, requests}
    end
  end

  defp next(leaders, database, slot_in, slot_out, requests, proposals, decisions) do
    receive do
      {:CLIENT_REQUEST, c} ->
        {new_slot_in, new_requests, new_proposals} = propose(leaders, slot_in, slot_out, requests++[c], proposals, decisions)
        next(leaders, database, new_slot_in, slot_out, new_requests, new_proposals, decisions)
      {:DECISION, s, c} ->
        new_decisions = decisions ++ [{s, c}]
        {new_proposals, new_requests} = allocate(database, slot_out, requests, proposals, new_decisions)
        {new_slot_in, new_requests_, new_proposals_} = propose(leaders, slot_in, slot_out, new_requests, new_proposals, new_decisions)
        next(leaders, database, new_slot_in, slot_out, new_requests_, new_proposals_, new_decisions)
    end
  end
end
