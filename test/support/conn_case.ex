defmodule PgLargeObjects.ConnCase do
  @moduledoc """
  Convenience module for creating test cases interacting with a LiveView UI.
  """
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      import PgLargeObjects.ConnCase
      import PgLargeObjects.Fixtures

      alias PgLargeObjects.TestRepo

      # The default endpoint for testing
      @endpoint PgLargeObjects.TestEndpoint
    end
  end

  setup tags do
    opts = [shared: not tags[:async]]

    pid = Sandbox.start_owner!(PgLargeObjects.TestRepo, opts)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    start_supervised!({Phoenix.PubSub, name: PgLargeObjects.TestPubSub})
    start_supervised!(PgLargeObjects.TestEndpoint)

    conn = Phoenix.ConnTest.build_conn()

    {:ok, conn: conn}
  end
end
