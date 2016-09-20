defmodule Backstage.Consumer do
  @moduledoc "Consumer"

  use Experimental.GenStage

  alias Experimental.GenStage
  alias Backstage.Job

  @name __MODULE__

  def start_link() do
    GenStage.start_link(__MODULE__, %{repo: nil}, name: @name)
  end

  ## Callbacks

  def init(state) do
    [{:repo, repo}] = :ets.lookup(:backstage, :repo)
    state = %{state | repo: repo}

    # TODO: make the subscription configurable {Backstage.Producer, Application.get_env(:backstage, :sub_opts)}
    {:consumer, state, subscribe_to: [{Backstage.Producer, min_demand: 0, max_demand: 1}]}
  end

  def handle_events(jobs, _from, %{repo: repo} = state) do
    running_jobs =
      for job <- jobs do
        task = start_task(job)
        timer_ref = :erlang.start_timer(job.timeout, self(), {task, job})
        {task.ref, %{job: job, timer_ref: timer_ref}}
      end
      |> Enum.into(%{})

    state = Map.put(state, :running_jobs, running_jobs)

    {:noreply, [], state}
  end

  def handle_info({ref, {:ok, job}}, %{repo: repo, running_jobs: running_jobs} = state) do
    IO.inspect {ref, job}

    timer_ref = running_jobs[ref][:timer_ref]
    :erlang.cancel_timer(timer_ref)

    Job.update_status(repo, job, "success")

    running_jobs = Map.delete(state.running_jobs, ref)
    state = %{state | running_jobs: running_jobs}

    {:noreply, [], state}
  end

  def handle_info({ref, {:error, job, reason}}, %{repo: repo, running_jobs: running_jobs} = state) do
    IO.inspect {ref, job, reason}

    timer_ref = running_jobs[ref][:timer_ref]
    :erlang.cancel_timer(timer_ref)

    Job.update_error(repo, job, "error", reason)

    running_jobs = Map.delete(state.running_jobs, ref)
    state = %{state | running_jobs: running_jobs}

    {:noreply, [], state}
  end

  def handle_info({:DOWN, ref, :process, pid, :normal}, state) do
    IO.inspect {ref, pid, :normal}

    # TODO: nothing to do here?

    {:noreply, [], state}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, %{repo: repo, running_jobs: running_jobs} = state) do
    IO.inspect {ref, pid, reason}

    timer_ref = running_jobs[ref][:timer_ref]
    :erlang.cancel_timer(timer_ref)

    job = running_jobs[ref][:job]
    Job.update_error(repo, job, "error", to_string(reason))

    running_jobs = Map.delete(state.running_jobs, ref)
    state = %{state | running_jobs: running_jobs}

    {:noreply, [], state}
  end

  def handle_info({:timeout, timer_ref, {task, job}}, %{repo: repo, running_jobs: running_jobs} = state) do
    IO.inspect {:timeout, timer_ref, task, job}

    if Process.alive?(task.pid) do
      Task.shutdown(task, :brutal_kill)
    end

    Job.update_error(repo, job, "error", "timed out after #{job.timeout} ms")

    running_jobs = Map.delete(state.running_jobs, task.ref)
    state = %{state | running_jobs: running_jobs}

    {:noreply, [], state}
  end

  defp start_task(job) do
    Task.Supervisor.async_nolink(Backstage.TaskSupervisor, Backstage.Job, :run, [job])
  end
end
