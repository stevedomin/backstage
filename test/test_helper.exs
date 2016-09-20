Logger.configure(level: :info)
ExUnit.start()

Code.require_file "./support/test_repo.exs", __DIR__
Code.require_file "./support/test_migration.exs", __DIR__

alias Backstage.TestRepo

Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

defmodule Backstage.IntegrationCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Backstage.TestRepo, as: Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(TestRepo, {:shared, self()})
    end

    :ok
  end
end

# Load up the repository, start it, and run migrations
_   = Ecto.Adapters.Postgres.storage_down(TestRepo.config)
:ok = Ecto.Adapters.Postgres.storage_up(TestRepo.config)

{:ok, _pid} = TestRepo.start_link
:ok = Ecto.Migrator.up(TestRepo, 0, Backstage.TestMigration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
Process.flag(:trap_exit, true)

