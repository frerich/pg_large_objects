defmodule PgLargeObjects.TestRepo do
  @moduledoc """
  Ecto repository used during tests.
  """

  use Ecto.Repo,
    otp_app: :pg_large_objects,
    adapter: Ecto.Adapters.Postgres

  use PgLargeObjects.Repo
end
