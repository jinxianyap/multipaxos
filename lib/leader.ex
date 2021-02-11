defmodule Leader do

def start(config) do
    config = Configuration.node_id(config, "Leader", self())
    Debug.starting(config)

    receive do
        {:BIND, acceptors, replicas} ->
            pn = {0, self()}
            spawn(Scout, :start, [config, self(), acceptors, pn])
            next(config, false, Map.new(), acceptors, replicas, pn)
    end
end

defp get_max_pn_for_each_slot(pvals) do
    slot_to_pn = Map.new()
    # IO.puts "all_pvals: #{inspect pvals}"
    for pval <- pvals do
        # IO.puts "pval: #{inspect pval}"
        {pn, slot_no, cmd} = pval
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

defp next(config, active, proposals, acceptors, replicas, pn) do
    receive do
        {:PROPOSE, slot, cmd} ->
            new_proposals =
            if Map.get(proposals, slot) == nil do
                updated_proposals = Map.put(proposals, slot, cmd)
                if active do
                    spawn(Commander, :start, [config, self(), acceptors, replicas, {pn, slot, cmd}])
                end
                updated_proposals
            else
                proposals
            end
            next(config, active, new_proposals, acceptors, replicas, pn)
        {:ADOPTED, pn_adopted, pvals} ->
            pmax = get_max_pn_for_each_slot(pvals)
            proposals = Map.merge(proposals, pmax)
            Enum.map(proposals, fn {s, c} -> spawn(Commander, :start, [config, self(), acceptors, replicas, {pn_adopted, s, c}]) end)
            active = true
            next(config, active, proposals, acceptors, replicas, pn)
        {:PREEMPTED, pn_accepted} ->
            if Util.compare_pn(pn_accepted, pn) == 1 do
                active = false
                {curr_round, _} = pn
                pn_new = {curr_round + 1, self()}
                spawn(Scout, :start, [config, self(), acceptors, pn_new])
                next(config, active, proposals, acceptors, replicas, pn_new)
            else
                next(config, active, proposals, acceptors, replicas, pn)
            end

    end
end
end
