defmodule Backstage.Job do
  use Ecto.Schema

  import Ecto.Query

  @callback run(payload :: map) :: none

  @running_status "running"
  @pending_status "pending"

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts], location: :keep do
      @behaviour Backstage.Job

      @priority opts[:priority] || 100
      @timeout opts[:timeout] || -1
      @retryable opts[:retryable] || true

      # def batch_enqueue([args]) || enqueue(args) when is_list(args)

      def enqueue(payload, opts \\ [])
      def enqueue(payload, opts) when is_map(payload) do
        opts =
          [priority: @priority, timeout: @timeout, retryable: @retryable]
          |> Keyword.merge(opts)

        Backstage.Job.enqueue(repo(), __MODULE__, payload, opts)
      end
      def enqueue(payload, _opts) do
        raise ArgumentError, "expected payload to be a map, got #{inspect(payload)}"
      end

      defp repo() do
        [{:repo, repo}] = :ets.lookup(:backstage, :repo)
        repo
      end
    end
  end

  schema "jobs" do
    field :module, :string
    field :payload, :map
    field :status, :string
    field :priority, :integer, default: 100
    field :timeout, :integer, default: -1
    field :scheduled_at, Ecto.DateTime
    field :retryable, :boolean
    field :failure_count, :integer, default: 0
    field :last_error, :string

    timestamps usec: true
  end

  def enqueue(repo, module, payload, opts \\ [priority: 100, timeout: -1, retryable: true]) do
    repo.insert(%__MODULE__{
      module: to_string(module),
      payload: payload,
      status: @pending_status,
      priority: opts[:priority],
      timeout: opts[:timeout],
      scheduled_at: opts[:scheduled_at],
      retryable: opts[:retryable]
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
        [set: [status: @running_status, updated_at: Ecto.DateTime.utc(:usec)]],
        [returning: true]
      )
    end
    {count, jobs}
  end

  def delete(repo, job_id) do
    [job_id]
    |> by_ids()
    |> repo.delete_all(returning: false)
  end

  def update_error(repo, job_id, status, error \\ nil) do
    [job_id]
    |> by_ids()
    |> repo.update_all(
      [set: [status: status, last_error: error, updated_at: Ecto.DateTime.utc(:usec)], inc: [failure_count: 1]],
      [returning: true]
    )
  end

  defp pending(limit) do
    from(j in __MODULE__,
      where: j.status == @pending_status and j.scheduled_at <= fragment("now()"),
      limit: ^limit,
      order_by: [desc: j.priority],
      select: j.id,
      lock: "FOR UPDATE SKIP LOCKED")
  end

  defp by_ids(ids) do
    from(j in __MODULE__, where: j.id in ^ids)
  end
end
