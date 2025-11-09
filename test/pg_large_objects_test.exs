defmodule PgLargeObjectsTest do
  use PgLargeObjects.DataCase, async: true
  doctest PgLargeObjects

  alias PgLargeObjects

  describe "import/2" do
    test "can import binary" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      {:ok, oid} =
        TestRepo.transact(fn ->
          PgLargeObjects.import(TestRepo, data)
        end)

      assert data == get_large_object!(oid)
    end
  end

  describe "export/3" do
    test "can export data to binary" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      oid = put_large_object!(data)

      assert {:ok, ^data} =
               TestRepo.transact(fn ->
                 PgLargeObjects.export(TestRepo, oid)
               end)
    end
  end
end
