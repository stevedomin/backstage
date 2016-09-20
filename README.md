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

## Ideas

### v1

* Pretty much a port of existing bg job systems (Que, etc.)
* Probably not using gen_stage at its full potential
  * n Consumers sending demands to 1 (n?) Producer
  * No complex pipelines or flow of messages
* All the logic for running the job, handling success/failures, etc. is split between the Consumer and Job module

### Next

* Maximise gen_stage's usage
  * Express pipelines rather than jobs
  * Could things like failure handling, retries, etc. be another consumer that you would decide to "plug" or not into your job pipeline
    * What happens when the job fails in the middle of the pipeline?
* Currently the only storage backend is Postgres but could we have an adapter based system?
    * redis
    * memory?

## Notes

* Logging
* Try/catch errors in jobs (exception tracking)
* Currently polling Postgres for new jobs every X ms. Could we use LISTEN/NOTIFY?
* Think about the implications of gen_stage events buffering
* Retries/backoff
* Erlang ETF is nice for prototyping but not as good for introspection and potential ports in other languages.
* Start the consumers/producers
  * Config to decide whether to add to the supervision tree automatically
  * Otherwise start with mix task
  * Config to decide how many producers/consumers you want
  * Think about benefits of having multiple producers
* Separate table for failed jobs?
* Vacuum the successful/failed jobs
* UI to list jobs, failures, retry, etc.
  * Separate package
* scheduler
* benchmarking

