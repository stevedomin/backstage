# Backstage

Backstage is a simple Elixir background job processing library backed by PostgreSQL.

## Usage

```elixir
defmodule MyApp.Jobs.WelcomeNotification do
  use Backstage.Job, repo: MyApp.Repo

  def run(%{user_id: user_id}) do
    user = Repo.get!(MyApp.User, user_id)
    UserEmail.welcome(user) |> Mailer.deliver!
  end
end

iex> {:ok, job} = MyApp.Jobs.WelcomeNotification.enqueue(%{user_id: user.id})
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `backstage` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:backstage, "~> 0.1.0"}]
    end
    ```

  2. Ensure `backstage` is started before your application:

    ```elixir
    def application do
      [applications: [:backstage]]
    end
    ```

  3. Start the `backstage` supervisor:

    ```elixir
    def start(_type, _args) do
      import Supervisor.Spec

      children = [
        supervisor(Backstage.Supervisor, [])
      ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end
    ```

## TODO

* Logging
* https://github.com/stevedomin/backstage/pull/1#discussion_r80389826
* Currently polling Postgres for new jobs every X ms. Could we use LISTEN/NOTIFY?
* Think about the implications of gen_stage events buffering
* Retries/backoff
* Separate table for failed jobs?
* Vacuum the successful/failed jobs
* UI to list jobs, failures, retry, etc.
  * Separate package
* scheduler
* benchmarking

