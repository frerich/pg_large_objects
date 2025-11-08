defmodule PgLargeObjectsTest do
  use ExUnit.Case, async: true
  doctest PgLargeObjects

  alias Ecto.Adapters.SQL.Sandbox, as: SQLSandbox
  alias PgLargeObjects
  alias PgLargeObjects.TestRepo

  setup do
    :ok = SQLSandbox.checkout(TestRepo)
  end

  describe "import/2" do
    test "can import data" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      {:ok, oid} =
        StringIO.open(data, [], fn pid ->
          {:ok, oid} = pid |> IO.binstream(4) |> PgLargeObjects.import(TestRepo)
          oid
        end)

      assert %{rows: [[^oid, ^data]]} =
               TestRepo.query!("SELECT loid, data FROM pg_largeobject", [])
    end
  end

  describe "export/3" do
    test "can export data" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      {:ok, oid} =
        TestRepo.transact(fn ->
          {:ok, lob} = PgLargeObjects.LargeObject.create(TestRepo)
          :ok = PgLargeObjects.LargeObject.write(lob, data)
          {:ok, lob.oid}
        end)

      assert {:ok, ^data} =
               StringIO.open("", [encoding: :latin1], fn pid ->
                 PgLargeObjects.export(oid, TestRepo, IO.binstream(pid, 4))
                 {_input, output} = StringIO.contents(pid)
                 output
               end)
    end
  end
end
