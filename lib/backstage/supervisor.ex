defmodule Backstage.Supervisor do
  use Supervisor

  def start_link(opts) do
    repo = Keyword.get(opts, :repo)
    Supervisor.start_link(__MODULE__, [repo: repo], [name: Backstage.Supervisor])
  end

  ## Callbacks

  def init([repo: repo]) do
    children = [
      worker(Backstage.Producer, [[repo: repo]]),
      worker(Backstage.Consumer, [[repo: repo]]),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
