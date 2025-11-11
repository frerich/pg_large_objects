defmodule PgLargeObjectsTest do
  use PgLargeObjects.DataCase, async: true
  doctest PgLargeObjects

  alias PgLargeObjects

  describe "import/2" do
    test "can import binary" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      {:ok, oid} =
        TestRepo.transaction(fn ->
          {:ok, oid} = PgLargeObjects.import(TestRepo, data)
          oid
        end)

      assert data == get_large_object!(oid)
    end

    test "can import from enumerable" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      {:ok, pid} = StringIO.open(data, encoding: :latin1)

      stream = IO.binstream(pid, 3)

      {:ok, oid} =
        TestRepo.transaction(fn ->
          {:ok, oid} = PgLargeObjects.import(TestRepo, stream)
          oid
        end)

      assert data == get_large_object!(oid)

      {:ok, _output} = StringIO.close(pid)
    end
  end

  describe "export/3" do
    test "can export data to binary" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      oid = put_large_object!(data)

      TestRepo.transaction(fn ->
        assert {:ok, ^data} = PgLargeObjects.export(TestRepo, oid)
      end)
    end

    test "can export data to collectable" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      oid = put_large_object!(data)

      {:ok, pid} = StringIO.open("", encoding: :latin1)
      stream = IO.binstream(pid, 3)

      TestRepo.transaction(fn ->
        assert :ok == PgLargeObjects.export(TestRepo, oid, into: stream)
      end)

      assert {"", ^data} = StringIO.contents(pid)
    end

    test "handles invalid object IDs" do
      TestRepo.transaction(fn ->
        assert {:error, :not_found} = PgLargeObjects.export(TestRepo, 12_345)
      end)
    end
  end
end
