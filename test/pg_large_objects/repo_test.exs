defmodule PgLargeObjects.RepoTest do
  use PgLargeObjects.DataCase, async: true

  describe "import_large_object/1" do
    test "can import binary" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      {:ok, oid} =
        TestRepo.transact(fn ->
          TestRepo.import_large_object(data)
        end)

      assert data == get_large_object!(oid)
    end
  end

  describe "export_large_object/1" do
    test "can export to binary" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      oid = put_large_object!(data)

      assert {:ok, ^data} =
               TestRepo.transact(fn ->
                 TestRepo.export_large_object(oid)
               end)
    end
  end
end
