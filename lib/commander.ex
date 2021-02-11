
defmodule Commander do
    def start(config, leader, acceptors, replicas, p_val, server_num) do
        config = Configuration.node_id(config, "Commander", self())
        Debug.starting(config)
        send config.monitor, { :COMMANDER_SPAWNED, server_num}

        for each <- acceptors do
            send each, {:ACCEPT, self(), p_val}
        end
        waitfor = acceptors
        next(config, leader, waitfor, acceptors, replicas, p_val, server_num)
    end

    defp next(config, leader, waitfor, acceptors, replicas, p_val, server_num) do
        {pn, s, cmd} = p_val
        receive do
            {:ACCEPTED, acceptor, pn_accepted} ->
                if pn_accepted == pn do
                    waitfor = List.delete(waitfor, acceptor)
                    if length(waitfor) < length(acceptors) / 2 do
                        for r <- replicas do
                            send r, {:DECISION, s, cmd}
                        end
                        send config.monitor, { :COMMANDER_FINISHED, server_num} 
                        Process.exit(self(), :normal)
                    else
                        next(config, leader, waitfor, acceptors, replicas, p_val, server_num)
                    end
                else
                    send leader, {:PREEMPTED, pn_accepted}
                    send config.monitor, { :COMMANDER_FINISHED, server_num} 
                    Process.exit(self(), :normal)
                end
        end
    end
end
