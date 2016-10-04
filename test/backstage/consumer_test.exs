defmodule Backstage.ConsumerTest do
  use Backstage.IntegrationCase, async: true

  import ExUnit.CaptureLog

  alias Backstage.Job
  alias Backstage.Consumer
  alias Backstage.Producer

  defmodule WorkingJob do
    use Backstage.Job

    def run(%{"pid" => pid}) do
      pid = :erlang.list_to_pid(pid)
      send(pid, :consumed)
    end
  end

  defmodule TimingOutJob do
    use Backstage.Job, timeout: 100

    def run(%{"pid" => pid}) do
      pid = :erlang.list_to_pid(pid)
      :timer.sleep(1000)
      send(pid, :consumed)
    end
  end

  defmodule FailingJob do
    use Backstage.Job

    def run(%{"pid" => _pid}) do
      raise "oops"
    end
  end

  setup do
    {:ok, producer} = Producer.start_link()
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), producer)
    {:ok, consumer} = Consumer.start_link()
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), consumer)

    #on_exit fn ->
    #  GenStage.stop(consumer)
    #  GenStage.stop(producer)
    #end

    {:ok, producer: producer, consumer: consumer}
  end

  test "enqueued jobs are consumed" do
    parent = :erlang.pid_to_list(self())

    for _ <- 1..10 do
      {:ok, _job} = WorkingJob.enqueue(%{pid: parent})
    end

    assert total_job_count() == 10

    for _ <- 1..10 do
      assert_receive :consumed, 2_000
    end

    # TODO: Find a way around this
    :timer.sleep(500)

    assert successful_job_count() == 10
  end

  test "jobs timing out" do
    parent = :erlang.pid_to_list(self())

    for _ <- 1..10 do
      {:ok, _job} = TimingOutJob.enqueue(%{pid: parent})
    end

    assert total_job_count() == 10

    # TODO: Find a way around this
    :timer.sleep(2000)

    assert timed_out_job_count() == 10
  end

  test "jobs raising" do
    parent = :erlang.pid_to_list(self())

    capture_log(fn ->
      for _ <- 1..10 do
        {:ok, _job} = FailingJob.enqueue(%{pid: parent})
      end

      assert total_job_count() == 10

      # TODO: Find a way around this
      :timer.sleep(1500)

      assert failed_job_count() == 10
    end) =~ "oops"
  end

  defp total_job_count(), do: Repo.one(from j in Job, select: count(j.id))
  defp successful_job_count(), do: Repo.one(from j in Job, where: j.status == "success", select: count(j.id))
  defp timed_out_job_count(), do: Repo.one(from j in Job, where: j.status == "error" and j.last_error == "timed out", select: count(j.id))
  defp failed_job_count(), do: Repo.one(from j in Job, where: j.status == "error", select: count(j.id))
end
