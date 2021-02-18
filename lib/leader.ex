# Jin Xian Yap (jxy18) and Emily Haw (eh4418)
defmodule Leader do

def start(config, server_num) do
    config = Configuration.node_id(config, "Leader", server_num)
    Debug.starting(config)

    receive do
        {:BIND, acceptors, replicas} ->
            pn = {0, server_num}
            spawn(Scout, :start, [config, self(), acceptors, pn, server_num])
            next(config, false, Map.new(), acceptors, replicas, pn, server_num)
    end
end

defp get_max_pn_for_each_slot(pvals) do
    slot_to_pn = Map.new()
    # IO.puts "all_pvals: #{inspect pvals}"
    for pval <- pvals do
        # IO.puts "pval: #{inspect pval}"
        {pn, slot_no, _cmd} = pval
        if Map.has_key?(slot_to_pn, slot_no) do
            {curr_highest_pn, _, _} = Map.get(slot_to_pn, slot_no)
            if pn > curr_highest_pn do
                Map.put(slot_to_pn, slot_no, pval)
            end
        else
            Map.put(slot_to_pn, slot_no, pval)
        end
    end

    new_proposals = Map.new(Enum.map(slot_to_pn, fn {k, {_, _, cmd}} -> {k, cmd} end))
    new_proposals
end

defp next(config, active, proposals, acceptors, replicas, pn, server_num) do
    receive do
        {:PROPOSE, slot, cmd} ->
            new_proposals =
            if Map.get(proposals, slot) == nil do
                updated_proposals = Map.put(proposals, slot, cmd)
                if active do
                    spawn(Commander, :start, [config, self(), acceptors, replicas, {pn, slot, cmd}, server_num])
                end
                updated_proposals
            else
                proposals
            end
            next(config, active, new_proposals, acceptors, replicas, pn, server_num)
        {:ADOPTED, pn_adopted, pvals} ->
            pmax = get_max_pn_for_each_slot(pvals)
            proposals = Map.merge(proposals, pmax)
            Enum.map(proposals, fn {s, c} -> spawn(Commander, :start, [config, self(), acceptors, replicas, {pn_adopted, s, c}, server_num]) end)
            active = true
            next(config, active, proposals, acceptors, replicas, pn, server_num)
        {:PREEMPTED, pn_accepted} ->
            if Util.compare_pn(pn_accepted, pn) == 1 do
                active = false
                {n_a, _} = pn_accepted
                {n, _} = pn
                Process.send_after(self(), {:RESPAWN}, min(abs(n_a-n) * 2, 1000))
                next(config, active, proposals, acceptors, replicas, pn, server_num)
            else
                next(config, active, proposals, acceptors, replicas, pn, server_num)
            end
        {:RESPAWN} ->
            {curr_round, _} = pn
            pn_new = {curr_round + 1, server_num}
            spawn(Scout, :start, [config, self(), acceptors, pn_new, server_num])
            next(config, active, proposals, acceptors, replicas, pn_new, server_num)
    end
end
end
