#acceptor module

defmodule Acceptor do

def start do
    next -1 []
end

defp next pn accepted do
    receive do
        {:prepare, sender, p_pn} -> 
            if p_pn > pn do
                pn = p_pn
            end
            send {sender, {:promise, self(), pn, accepted}} 
            next pn accepted    
        {:accept, sender, {p_pn, slot, cmd} = p_v} ->
            if pn == p_pn do
                accepted = accepted ++ [p_v]
            end
            send {sender, {:accepted, self(), pn} }
            next pn accepted
    end    
end

end