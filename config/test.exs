use Mix.Config

config :backstage, Backstage.TestRepo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "backstage_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :backstage, repo: Backstage.TestRepo
