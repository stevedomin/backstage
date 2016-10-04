defmodule Backstage.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Task.Supervisor, [[name: Backstage.TaskSupervisor]])
    ]

    opts = [strategy: :one_for_one, name: Backstage.ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end
