# Jin Xian Yap (jxy18) and Emily Haw (eh4418)

defmodule Acceptor do

def start(config) do
    config = Configuration.node_id(config, "Acceptor", self())
    Debug.starting(config)
    next({-1, :c.pid(0, 0, 0)}, [])
end

defp next(highest_pn_so_far, accepted) do
    receive do
        {:PREPARE, scout, p_pn} ->
            new_highest_pn_so_far =
            if Util.compare_pn(p_pn, highest_pn_so_far) == 1 do
                p_pn
            else
                highest_pn_so_far
            end

            send scout, {:PROMISE, self(), new_highest_pn_so_far, accepted}
            next new_highest_pn_so_far, accepted
        {:ACCEPT, commander, {p_pn, _, _} = p_v} ->
            new_accepted =
            if Util.compare_pn(highest_pn_so_far, p_pn) == 0 do
                accepted ++ [p_v]
            else
                accepted
            end

            send commander, {:ACCEPTED, self(), highest_pn_so_far}
            next highest_pn_so_far, new_accepted
    end
end

end
