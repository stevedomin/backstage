defmodule Backstage.Consumer do
  @moduledoc "Consumer"

  use GenStage

  alias Backstage.TaskSupervisor
  alias Backstage.Job

  @name __MODULE__

  def start_link(opts) do
    repo = Keyword.get(opts, :repo)
    GenStage.start_link(__MODULE__, %{repo: repo, running_jobs: %{}}, name: @name)
  end

  ## Callbacks

  def init(state) do
    # TODO: make the subscription configurable {Backstage.Producer, Application.get_env(:backstage, :sub_opts)}
    {:consumer, state, subscribe_to: [Backstage.Producer]}
  end

  def handle_events(jobs, _from, %{running_jobs: running_jobs} = state) do
    running_jobs =
      for job <- jobs, into: running_jobs do
        task = start_task(job)
        timer = start_timer(job, task)
        {task.ref, %{task: task, job_id: job.id, timer: timer}}
      end

    state = Map.put(state, :running_jobs, running_jobs)

    {:noreply, [], state}
  end

  def handle_info({ref, _reply}, %{repo: repo, running_jobs: running_jobs} = state) do
    Process.demonitor(ref, [:flush])

    {%{job_id: job_id, timer: timer}, running_jobs} = Map.pop(running_jobs, ref)
    state = %{state | running_jobs: running_jobs}

    :ok = cancel_timer(timer)

    handle_success(repo, job_id)

    {:noreply, [], state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{repo: repo, running_jobs: running_jobs} = state) do
    {%{job_id: job_id, timer: timer}, running_jobs} = Map.pop(running_jobs, ref)
    state = %{state | running_jobs: running_jobs}

    :ok = cancel_timer(timer)

    case reason do
      :normal ->
        handle_success(repo, job_id)
      reason ->
        formatted_error = Exception.format_exit(reason)
        Job.update_error(repo, job_id, "error", formatted_error)
    end

    {:noreply, [], state}
  end

  def handle_info({:timeout, _timer_ref, task_ref}, %{repo: repo, running_jobs: running_jobs} = state) do
    {%{task: task, job_id: job_id}, running_jobs} = Map.pop(running_jobs, task_ref)
    state = %{state | running_jobs: running_jobs}

    case Task.shutdown(task, :brutal_kill) do
      {:ok, _reply} ->
        handle_success(repo, job_id)
      {:exit, :normal} ->
        handle_success(repo, job_id)
      {:exit, reason} ->
        formatted_error = Exception.format_exit(reason)
        Job.update_error(repo, job_id, "error", formatted_error)
      nil ->
        Job.update_error(repo, job_id, "error", "timed out")
    end

    {:noreply, [], state}
  end

  defp handle_success(repo, job_id) do
    Job.delete(repo, job_id)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer) do
    case :erlang.cancel_timer(timer) do
      false ->
        receive do
          {:timeout, ^timer, _} -> :ok
        after
          0 -> raise "timer could not be found"
        end
      rem when is_integer(rem) ->
        :ok
    end
  end

  defp start_task(job) do
    Task.Supervisor.async_nolink(TaskSupervisor, String.to_atom(job.module), :run, [job.payload])
  end

  defp start_timer(%Job{timeout: -1}, _task), do: nil
  defp start_timer(job, task) do
    :erlang.start_timer(job.timeout, self(), task.ref)
  end
end
