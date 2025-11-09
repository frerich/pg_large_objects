defmodule PgLargeObjects.DataCase do
  @moduledoc """
  Convenience module for creating test cases interacting with the database.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias PgLargeObjects.TestRepo

      import PgLargeObjects.DataCase
      import PgLargeObjects.Fixtures
    end
  end

  setup tags do
    opts = [shared: not tags[:async]]

    pid = Sandbox.start_owner!(PgLargeObjects.TestRepo, opts)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    :ok
  end
end
