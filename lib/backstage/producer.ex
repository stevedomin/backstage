defmodule Backstage.Producer do
  @moduledoc "Producer"

  use Experimental.GenStage

  alias Experimental.GenStage
  alias Backstage.Job

  @name __MODULE__

  def start_link() do
    GenStage.start_link(__MODULE__, %{repo: nil, count: 0}, name: @name)
  end

  ## Callbacks

  def init(state) do
    repo = Application.get_env(:backstage, :repo)
    table = :ets.new(:backstage, [:named_table, :set, :protected])
    :ets.insert(table, {:repo, repo})

    state = %{state | repo: repo}

    #Process.send_after(self(), :poll, 10_000)
    {:producer, state}
  end

  def handle_demand(demand, %{repo: repo, count: count}) do
    send_jobs(repo, demand + count)
  end

  def handle_info(:poll, state) do
    #Process.send_after(self(), :poll, 10_000)
    #send_jobs(state)
  end

  defp send_jobs(repo, 0) do
    {:noreply, [], %{repo: repo, count: 0}}
  end
  defp send_jobs(repo, limit) when limit > 0 do
    {count, jobs} = Job.take(repo, limit)
    {:noreply, jobs, %{repo: repo, count: limit - count}}
  end
end
