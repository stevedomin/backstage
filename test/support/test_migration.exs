defmodule Backstage.TestMigration do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :module, :text, null: false
      add :payload, :json, null: false, default: fragment("'{}'::json")
      add :status, :string, null: false
      add :priority, :smallint, null: false, default: 100
      add :timeout, :integer, null: false
      add :failure_count, :integer, null: false, default: 0
      add :last_error, :text

      timestamps()
    end
  end
end
