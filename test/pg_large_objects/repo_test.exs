defmodule PgLargeObjects.RepoTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL.Sandbox, as: SQLSandbox
  alias PgLargeObjects.TestRepo

  setup do
    :ok = SQLSandbox.checkout(TestRepo)
  end

  describe "import_large_object/1" do
    test "can import data" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      {:ok, oid} =
        StringIO.open(data, [], fn pid ->
          {:ok, oid} = pid |> IO.binstream(4) |> TestRepo.import_large_object()
          oid
        end)

      assert %{rows: [[^oid, ^data]]} =
               TestRepo.query!("SELECT loid, data FROM pg_largeobject", [])
    end
  end
end
