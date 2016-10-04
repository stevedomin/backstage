defmodule Backstage.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], [name: Backstage.Supervisor])
  end

  ## Callbacks

  def init([]) do
    true = prepare_repo()

    children = [
      worker(Backstage.Producer, []),
      worker(Backstage.Consumer, []),
    ]

    supervise(children, strategy: :one_for_one)
  end

  defp prepare_repo() do
    repo = Application.get_env(:backstage, :repo)
    table = :ets.new(:backstage, [:named_table, :set, :protected])
    :ets.insert(table, {:repo, repo})
  end
end
