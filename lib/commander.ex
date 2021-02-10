
defmodule Commander do
    def start(config, leader, acceptors, replicas, p_val) do
        config = Configuration.node_id(config, "Commander", self())
        Debug.starting(config)

        for each <- acceptors do
            send each, {:ACCEPT, self(), p_val}
        end
        waitfor = acceptors
        next(leader, waitfor, acceptors, replicas, p_val)
    end

    defp next(leader, waitfor, acceptors, replicas, p_val) do
        {pn, s, cmd} = p_val
        receive do
            {:ACCEPTED, acceptor, pn_accepted} ->
                if pn_accepted == pn do
                    waitfor = List.delete(waitfor, acceptor)
                    if length(waitfor) < length(acceptors) / 2 do
                        for r <- replicas do
                            send r, {:DECISION, s, cmd}
                        end
                        Process.exit(self(), :normal)
                    else
                        next(leader, waitfor, acceptors, replicas, p_val)
                    end
                else
                    send leader, {:PREEMPTED, pn_accepted}
                    Process.exit(self(), :normal)
                end
        end
    end
end
