
defmodule Commander do
    def start(config, leader, acceptors, replicas, p_v) do
        config = Configuration.node_id(config, "Commander", self())
        Debug.starting(config)

        for each <- acceptors do
            send each, {:accept, self(), p_v}
        end
        waitfor = acceptors
        next(leader, waitfor, acceptors, replicas, p_v)
    end

    defp next(leader, waitfor, acceptors, replicas, p_v) do
        {pn, s, cmd} = p_v
        receive do
            {:accepted, acceptor, pn_accepted} ->
                if pn_accepted == pn do
                    waitfor = List.delete(waitfor, acceptor)
                    if length(waitfor) < length(acceptors) / 2 do
                        for r <- replicas do
                            send r, {:decision, s, cmd}
                        end
                        Process.exit(self(), :normal)
                    else
                        next(leader, waitfor, acceptors, replicas, p_v)
                    end
                else
                    send leader, {:preempted, pn_accepted}
                    Process.exit(self(), :normal)
                end
        end
    end
end
