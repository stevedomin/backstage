defmodule Backstage.Producer do
  @moduledoc "Producer"

  use GenStage

  alias Backstage.Job

  @name __MODULE__

  def start_link(opts) do
    repo = Keyword.get(opts, :repo)
    GenStage.start_link(__MODULE__, %{repo: repo, count: 0}, name: @name)
  end

  ## Callbacks

  def init(state) do
    Process.send_after(self(), :poll, poll_interval())
    {:producer, state}
  end

  def handle_demand(demand, %{repo: repo, count: count}) do
    send_jobs(repo, demand + count)
  end

  def handle_info(:poll, %{repo: repo, count: count}) do
    Process.send_after(self(), :poll, poll_interval())
    send_jobs(repo, count)
  end

  defp send_jobs(repo, 0) do
    {:noreply, [], %{repo: repo, count: 0}}
  end
  defp send_jobs(repo, limit) when limit > 0 do
    {count, jobs} = Job.take(repo, limit)
    {:noreply, jobs, %{repo: repo, count: limit - count}}
  end

  defp poll_interval do
    Application.get_env(:backstage, :poll_interval) || 1000
  end
end
