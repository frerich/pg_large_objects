defmodule PgLargeObjects.EctoQueryTest do
  use PgLargeObjects.DataCase, async: true

  import Ecto.Query
  import PgLargeObjects.EctoQuery

  describe "lo_create" do
    test "creates a large object via Ecto query" do
      query = from(x in fragment("SELECT 1 AS n"), select: lo_create())
      assert [oid] = TestRepo.all(query)
      assert is_integer(oid) and oid > 0
    end
  end

  describe "lo_unlink" do
    test "deletes a large object via Ecto query" do
      oid = put_large_object!("test data")

      values = [%{oid: oid}]
      types = %{oid: :integer}

      query = from(x in values(values, types), select: lo_unlink(x.oid))
      TestRepo.all(query)

      # Verify it's gone
      assert {:error, :not_found} = PgLargeObjects.LargeObject.open(TestRepo, oid)
    end
  end
end
