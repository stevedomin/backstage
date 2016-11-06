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

  describe "macro Backstage.Job.new/1" do
    test "returns job with default options" do
      job = FakeWorkingJob.new(%{})
      assert job.status == "pending"
      assert job.priority == 100
      assert job.timeout == -1
      assert job.scheduled_at == nil
      assert job.retryable == true
    end

    test "raises when payload is not a map" do
      message = ~s(expected payload to be a map, got "testing")
      assert_raise ArgumentError, message, fn ->
        FakeWorkingJob.new("testing")
      end
    end
  end

  describe "Backstage.Job.delete/2" do
    test "deletes the job" do
      assert total_job_count() == 0
      assert {:ok, job} = FakeWorkingJob.new(%{}) |> Repo.insert
      assert total_job_count() == 1
      assert {1, nil} = Job.delete(Repo, job.id)
      assert total_job_count() == 0
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

    test "does not return jobs scheduled in the future", %{pending_job_count: pending_job_count} do
      assert pending_job_count() == pending_job_count

      {{y, m, d}, time} = Ecto.DateTime.to_erl(Ecto.DateTime.utc)
      future_date = Ecto.DateTime.from_erl({{y+1, m, d}, time})

      FakeWorkingJob.new(%{}, scheduled_at: future_date)
      |> Repo.insert

      assert {^pending_job_count, _jobs} = Job.take(Repo, 1000)
    end
  end

  defp enqueue_sample_jobs(_context) do
    working_job_count = :rand.uniform(100)
    failing_job_count = :rand.uniform(100)
    important_job_count = :rand.uniform(100)
    pending_job_count = working_job_count + failing_job_count + important_job_count

    # enqueue a couple of working jobs
    for _ <- 1..working_job_count, do: {:ok, _job} = FakeWorkingJob.new(%{}) |> Repo.insert
    # enqueue a couple of failing jobs
    for _ <- 1..failing_job_count, do: {:ok, _job} = FakeFailingJob.new(%{}) |> Repo.insert
    # enqueue a couple of jobs with higher priority
    for _ <- 1..important_job_count, do: {:ok, _job} = FakeImportantJob.new(%{}) |> Repo.insert

    {:ok, working_job_count: working_job_count,
          failing_job_count: failing_job_count,
          important_job_count: important_job_count,
          pending_job_count: pending_job_count}
  end

  defp total_job_count(), do: Repo.one(from j in Job, select: count(j.id))
  defp pending_job_count(), do: Repo.one(from j in Job, select: count(j.id), where: j.status == "pending")
end
