#acceptor module

defmodule Acceptor do

def start(config) do
    config = Configuration.node_id(config, "Acceptor", self())
    Debug.starting(config)
    next(-1, [])
end

defp next(pn, accepted) do
    receive do
        {:prepare, leader, p_pn} ->
            if p_pn > pn do
                pn = p_pn
            end
            send leader, {:promise, self(), pn, accepted}
            next pn, accepted
        {:accept, leader, {p_pn, slot, cmd} = p_v} ->
            if pn == p_pn do
                accepted = accepted ++ [p_v]
            end
            send leader, {:accepted, self(), pn}
            next pn, accepted
    end
end

end
