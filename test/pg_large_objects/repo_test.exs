defmodule PgLargeObjects.RepoTest do
  use PgLargeObjects.DataCase, async: true

  describe "import_large_object/1" do
    test "can import binary" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      {:ok, oid} =
        TestRepo.transaction(fn ->
          {:ok, oid} = TestRepo.import_large_object(data)
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
          {:ok, oid} = TestRepo.import_large_object(stream)
          oid
        end)

      assert data == get_large_object!(oid)

      {:ok, _output} = StringIO.close(pid)
    end
  end

  describe "export_large_object/1" do
    test "can export to binary" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      oid = put_large_object!(data)

      assert {:ok, ^data} =
               TestRepo.transaction(fn ->
                 {:ok, data} = TestRepo.export_large_object(oid)
                 data
               end)
    end

    test "can export data to collectable" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      oid = put_large_object!(data)

      {:ok, pid} = StringIO.open("", encoding: :latin1)
      stream = IO.binstream(pid, 3)

      TestRepo.transaction(fn ->
        assert :ok == TestRepo.export_large_object(oid, into: stream)
      end)

      assert {"", ^data} = StringIO.contents(pid)
    end
  end
end
