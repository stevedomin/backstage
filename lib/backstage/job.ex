defmodule Backstage.Job do
  use Ecto.Schema

  import Ecto.Query

  @callback run(args :: any) :: any

  @running_status "running"
  @pending_status "pending"

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts], location: :keep do
      @behaviour Backstage.Job

      @priority opts[:priority] || 100
      @timeout opts[:timeout] || -1

      # def batch_enqueue([args]) || enqueue(args) when is_list(args)

      # TODO: Is the guard necessary or should we enforce getting a map as an argument?
      # TODO: allow overriding 'priority' when enqueuing a job
      def enqueue(args) when is_list(args) do
        Backstage.Job.enqueue(repo(), __MODULE__, args, [priority: @priority, timeout: @timeout])
      end
      def enqueue(args) do
        enqueue([args])
      end

      defp repo() do
        [{:repo, repo}] = :ets.lookup(:backstage, :repo)
        repo
      end
    end
  end

  schema "jobs" do
    field :status, :string
    field :priority, :integer, default: 100
    field :timeout, :integer, default: -1
    # field :started_at, DateTime
    # field :scheduled_at, DateTime
    # field :retryable, bool
    field :failure_count, :integer, default: 0
    field :last_error, :string
    field :payload, :binary

    timestamps usec: true
  end

  # TODO: think about whether we want to enforce jobs having to return :ok to indicate they're successful
  # The alternative is to assume the job is successful if it returns anything except {:error, reason}
  def run(%__MODULE__{} = job) do
    {mod, fun, args} = :erlang.binary_to_term(job.payload)
    case apply(mod, fun, args) do
      :ok -> {:ok, job}
      {:error, reason} -> {:error, job, reason}
      other ->
        {:error, job, :bad_return_value}
    end
  rescue
    error ->
      formatted_error = Exception.format(:error, error)
      # TODO: is it worth passing the raw exception as well? Might be useful for
      # 3rd party error handler
      {:error, job, formatted_error}
  end

  # TODO: guard with when is_map(args)?
  def enqueue(repo, mod, args, opts \\ [priority: 100, timeout: -1, scheduled_at: nil]) do
    repo.insert(%__MODULE__{
      status: @pending_status,
      priority: opts[:priority],
      timeout: opts[:timeout],
      # TODO: might be worth not hardcoding :run here
      payload: :erlang.term_to_binary({mod, :run, args}),
    })
  end

  # TODO: When limit > 1 the batch that will be returned by this function won't
  # be ordered. As in you could have jobs with higher priority at the end of the list.
  # It is however guaranteed that you will get the highest priority jobs from the database.
  # as there is an ORDER BY clause when fetching the pending jobs.
  def take(repo, limit) do
    {:ok, {count, jobs}} = repo.transaction fn ->
      limit
      |> pending()
      |> repo.all()
      |> by_ids()
      |> repo.update_all(
        # TODO: should this be set to an intermediary status like "processed"?
        # And then to running when the job has actually reached a consumer
        [set: [status: @running_status, updated_at: Ecto.DateTime.utc]],
        [returning: true]
      )
    end
    {count, jobs}
  end

  def update_status(repo, job, status) do
    # TODO: validate status?
    [job.id]
    |> by_ids()
    |> repo.update_all(
      [set: [status: status, updated_at: Ecto.DateTime.utc]],
      [returning: true]
    )
  end

  def update_error(repo, job, status, error \\ nil) do
    # TODO: validate status?
    [job.id]
    |> by_ids()
    |> repo.update_all(
      [set: [status: status, last_error: error, updated_at: Ecto.DateTime.utc], inc: [failure_count: 1]],
      [returning: true]
    )
  end

  defp pending(limit) do
    from(j in __MODULE__,
      where: j.status == @pending_status,
      limit: ^limit,
      order_by: [desc: j.priority],
      select: j.id,
      lock: "FOR UPDATE SKIP LOCKED")
  end

  defp by_ids(ids) do
    from(j in __MODULE__, where: j.id in ^ids)
  end
end
