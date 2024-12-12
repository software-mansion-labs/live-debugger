defmodule LiveDebugger.Service.Monitor do
  def liveview_pids() do
    Process.list()
    |> Enum.reject(&(&1 == self()))
    |> Enum.map(&{&1, process_initial_call(&1)})
    |> Enum.filter(fn {_, initial_call} -> liveview?(initial_call) end)
    |> Enum.map(&elem(&1, 0))
  end

  defp process_initial_call(pid) do
    pid
    |> Process.info([:dictionary])
    |> hd()
    |> elem(1)
    |> Keyword.get(:"$initial_call", {})
  end

  defp liveview?(initial_call) when initial_call not in [nil, {}] do
    elem(initial_call, 1) == :mount
  end

  defp liveview?(_), do: false
end
