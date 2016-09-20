defmodule Backstage.JobTest do
  use Backstage.IntegrationCase, async: true

  alias Backstage.Job

  defmodule FakeWorkingJob do
    use Backstage.Job
    def run(_arg), do: :ok
  end

  defmodule FakeFailingJob do
    use Backstage.Job
    def run(_arg), do: raise :oops
  end

  defmodule FakeImportantJob do
    use Backstage.Job, priority: 120
    def run(_arg), do: :important
  end

  setup_all do
    table = :ets.new(:backstage, [:named_table, :set, :protected])
    :ets.insert(table, {:repo, Repo})

    :ok
  end

  describe "Backstage.Job.enqueue/3" do
    test "returns {:ok, job} when successful" do
      assert total_job_count() == 0
      assert {:ok, _job} = Job.enqueue(Repo, __MODULE__, %{})
      assert total_job_count() == 1
    end

    test "returns {:error, reason} when it fails"

    test "is rollbacked if the transaction is aborted" do
      assert total_job_count() == 0
      Repo.transaction fn ->
        assert {:ok, _job} = Job.enqueue(Repo, __MODULE__, %{})
        Repo.rollback(:random_error_during_tx)
      end
      assert total_job_count() == 0
    end
  end

  describe "Backstage.Job.run/3" do
    test "is successful" do
      assert :ok == Job.run(FakeWorkingJob, :run, [%{}])
    end

    test "rescues any error raised" do
      assert {:error, _reason} = Job.run(FakeFailingJob, :run, [%{}])
    end

    test "returns a formatted message with stacktrace if an error was raised" do
      assert {:error, reason} = Job.run(FakeFailingJob, :run, [%{}])
      assert reason =~ """
        ** (UndefinedFunctionError) function :oops.exception/1 is undefined (module :oops is not available)
        """
    end
  end

  describe "Backstage.Job.take/2" do
    setup [:enqueue_sample_jobs]

    test "sets the status of the jobs it fetches to running", %{pending_job_count: pending_job_count} do
      assert {^pending_job_count, jobs} = Job.take(Repo, 1000)
      for job <- jobs do
        assert job.status == "running"
      end

      db_jobs = Repo.all(Job)
      for job <- db_jobs do
        assert job.status == "running"
      end
    end

    test "returns only returns the pending jobs", %{pending_job_count: pending_job_count} do
      assert pending_job_count() == pending_job_count
      assert {^pending_job_count, _jobs} = Job.take(Repo, 1000)

      assert pending_job_count() == 0
      assert {0, []} = Job.take(Repo, 100)
    end

    test "returns jobs ordered by their priority", %{important_job_count: important_job_count} do
      assert {^important_job_count, jobs} = Job.take(Repo, important_job_count)
      assert Enum.all?(jobs, fn (job) -> job.priority == 120 end)
    end
  end

  defp enqueue_sample_jobs(_context) do
    working_job_count = :rand.uniform(100)
    failing_job_count = :rand.uniform(100)
    important_job_count = :rand.uniform(100)
    pending_job_count = working_job_count + failing_job_count + important_job_count

    # enqueue a couple of working jobs
    for _ <- 1..working_job_count, do: {:ok, _job} = FakeWorkingJob.enqueue(%{})
    # enqueue a couple of failing jobs
    for _ <- 1..failing_job_count, do: {:ok, _job} = FakeFailingJob.enqueue(%{})
    # enqueue a couple of jobs with higher priority
    for _ <- 1..important_job_count, do: {:ok, _job} = FakeImportantJob.enqueue(%{})

    {:ok, working_job_count: working_job_count,
          failing_job_count: failing_job_count,
          important_job_count: important_job_count,
          pending_job_count: pending_job_count}
  end

  defp total_job_count(), do: Repo.one(from j in Job, select: count(j.id))
  defp pending_job_count(), do: Repo.one(from j in Job, select: count(j.id), where: j.status == "pending")
end
