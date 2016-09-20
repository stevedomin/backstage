defmodule Backstage.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], [name: Backstage.Supervisor])
  end

  ## Callbacks

  def init([]) do
    children = [
      supervisor(Task.Supervisor, [[name: Backstage.TaskSupervisor]]),
      worker(Backstage.Producer, []),
      worker(Backstage.Consumer, []),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
