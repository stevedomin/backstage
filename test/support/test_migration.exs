defmodule Backstage.TestMigration do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :status, :string, null: false
      add :priority, :integer, null: false
      add :timeout, :integer, null: false
      add :payload, :binary, null: false
      add :failure_count, :integer, null: false, default: 0
      add :last_error, :text

      timestamps()
    end
  end
end
