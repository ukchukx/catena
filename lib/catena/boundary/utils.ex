defmodule Catena.Boundary.Utils do
  @spec child_pid?(tuple, atom) :: boolean
  @spec id_from_pid(tuple, atom, atom) :: [binary]

  def child_pid?({:undefined, pid, :worker, [mod]}, mod) when is_pid(pid), do: true
  def child_pid?(_child, _module), do: false

  def id_from_pid({:undefined, pid, :worker, [mod]}, registry, mod),
    do: Registry.keys(registry, pid)
end
