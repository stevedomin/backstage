defmodule Mix.Tasks.Backstage.CreateJobMigration do
  use Mix.Task
  import Mix.Generator
  import Mix.Ecto

  @migration_name "CreateJob"

  def run(args) do
    path = "#{Mix.Project.app_path}/priv/repo/migrations/"
    Mix.Task.run "app.start", args
    repo = parse_repo(args) |> hd
    filename = "#{timestamp()}_create_job.exs"
    file = Path.join(path, filename)
    create_directory path
    create_file file, migration_template(mod:
                        Module.concat([repo, Migrations, @migration_name]))
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.replace(~r/[^0-9]/, "")
    |> String.slice(0..13)
  end

  embed_template :migration, """
  defmodule <%= inspect @mod %> do
    use Ecto.Migration

    def change do
      create table(:jobs) do
        add :module, :text, null: false
        add :payload, :json, null: false, default: fragment("'{}'::json")
        add :status, :string, null: false
        add :priority, :smallint, null: false, default: 100
        add :timeout, :integer, null: false
        add :scheduled_at, :datetime, null: false, default: fragment("now()")
        add :retryable, :boolean, null: false, default: true
        add :failure_count, :integer, null: false, default: 0
        add :last_error, :text

        timestamps()
      end
    end
  end
  """
end
