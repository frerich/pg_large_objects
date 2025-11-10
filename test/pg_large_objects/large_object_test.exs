defmodule PgLargeObjects.LargeObjectTest do
  use PgLargeObjects.DataCase, async: true

  alias PgLargeObjects.LargeObject

  describe "create/2" do
    test "creates a new object given a repo module" do
      assert {:ok, %LargeObject{oid: oid}} = LargeObject.create(TestRepo)
      assert %{rows: [[^oid]]} = TestRepo.query!("SELECT oid FROM pg_largeobject_metadata")
    end
  end

  describe "open/3" do
    test "succeeds given valid object ID" do
      oid = put_large_object!("Dummy data.")

      assert {:ok, %LargeObject{}} = LargeObject.open(TestRepo, oid)
    end

    test "fails given invalid object ID" do
      assert {:error, :not_found} == LargeObject.open(TestRepo, 12_345)
    end
  end

  describe "remove/2" do
    test "succeeds given valid object ID" do
      oid = put_large_object!("Dummy data.")

      assert :ok == LargeObject.remove(TestRepo, oid)

      assert %{rows: []} = TestRepo.query!("SELECT oid FROM pg_largeobject_metadata")
    end

    test "fails given invalid object ID" do
      assert {:error, :not_found} == LargeObject.open(TestRepo, 12_345)
    end
  end

  describe "close/1" do
    test "succeeds given valid object" do
      with_object("", fn lob ->
        assert :ok == LargeObject.close(lob)
      end)
    end

    test "fails given invalid object" do
      with_object("", fn lob ->
        :ok = LargeObject.remove(TestRepo, lob.oid)
        assert {:error, :not_found} == LargeObject.close(lob)
      end)
    end
  end

  describe "size/1" do
    test "succeeds given valid object" do
      with_object(:crypto.strong_rand_bytes(1024), fn lob ->
        assert {:ok, 1024} == LargeObject.size(lob)
      end)
    end

    test "fails given invalid object" do
      with_object(:crypto.strong_rand_bytes(1024), fn lob ->
        :ok = LargeObject.remove(TestRepo, lob.oid)
        assert {:error, :not_found} == LargeObject.size(lob)
      end)
    end
  end

  describe "write/2" do
    test "succeeds given valid object" do
      data = :crypto.strong_rand_bytes(Enum.random(0..1024))

      {:ok, oid} =
        with_object("", [mode: :write], fn lob ->
          assert :ok == LargeObject.write(lob, data)
        end)

      assert get_large_object!(oid) == data
    end

    test "maintains write position" do
      {:ok, oid} =
        with_object("", [mode: :write], fn lob ->
          assert :ok == LargeObject.write(lob, "Dummy data.")
          assert :ok == LargeObject.write(lob, "Dummy data.")
          assert :ok == LargeObject.write(lob, "Dummy data.")
        end)

      assert get_large_object!(oid) == "Dummy data.Dummy data.Dummy data."
    end

    test "overwrites existing data" do
      {:ok, oid} =
        with_object("ABCDEFG", [mode: :write], fn lob ->
          assert :ok == LargeObject.write(lob, "XYZ")
        end)

      assert get_large_object!(oid) == "XYZDEFG"
    end

    test "fails given invalid object" do
      with_object("", [mode: :write], fn lob ->
        :ok = LargeObject.remove(TestRepo, lob.oid)
        assert {:error, :not_found} == LargeObject.write(lob, "Dummy")
      end)
    end

    test "fails given object opened read-only" do
      with_object("ABCDEFG", [mode: :read], fn lob ->
        assert {:error, :read_only} == LargeObject.write(lob, "XYZ")
      end)
    end
  end

  describe "read/2" do
    test "succeeds given valid object" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, "ABCDEFG"} == LargeObject.read(lob, 7)
      end)
    end

    test "succeeds if given length is smaller than object size" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, "ABC"} == LargeObject.read(lob, 3)
      end)
    end

    test "succeeds if given length is larger than object size" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, "ABCDEFG"} == LargeObject.read(lob, 1000)
      end)
    end

    test "succeeds reading zero bytes" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, ""} == LargeObject.read(lob, 0)
      end)
    end

    test "maintains read position" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, "AB"} == LargeObject.read(lob, 2)
        assert {:ok, "CD"} == LargeObject.read(lob, 2)
        assert {:ok, "EF"} == LargeObject.read(lob, 2)
        assert {:ok, "G"} == LargeObject.read(lob, 2)
      end)
    end

    test "fails given invalid object" do
      with_object("ABCDEFG", fn lob ->
        :ok = LargeObject.remove(TestRepo, lob.oid)
        assert {:error, :not_found} == LargeObject.read(lob, 100)
      end)
    end
  end

  describe "seek/3" do
    test "succeeds adjusting write position given valid object" do
      {:ok, oid} =
        with_object("ABCDEFG", [mode: :write], fn lob ->
          assert {:ok, 3} = LargeObject.seek(lob, 3)
          :ok = LargeObject.write(lob, "XY")
        end)

      assert get_large_object!(oid) == "ABCXYFG"
    end

    test "succeeds adjusting read position given valid object" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, 3} = LargeObject.seek(lob, 3)
        assert {:ok, "DE"} == LargeObject.read(lob, 2)
      end)
    end

    test "succeeds seeking relative to current position" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, 3} = LargeObject.seek(lob, 3)
        assert {:ok, 5} = LargeObject.seek(lob, 2, :current)
        assert {:ok, "F"} == LargeObject.read(lob, 1)

        # Position is 2 since read/2 also moved the position +1
        assert {:ok, 2} = LargeObject.seek(lob, -4, :current)

        assert {:ok, "C"} == LargeObject.read(lob, 1)
      end)
    end

    test "succeeds seeking from end of object" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, 6} = LargeObject.seek(lob, -1, :end)
        assert {:ok, "G"} == LargeObject.read(lob, 1)
      end)
    end

    test "succeeds seeking zero bytes" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, 0} = LargeObject.seek(lob, 0, :start)
        assert {:ok, "A"} == LargeObject.read(lob, 1)
        assert {:ok, 1} = LargeObject.seek(lob, 0, :current)
        assert {:ok, "B"} == LargeObject.read(lob, 1)

        # Seeting to 0 bytes from the end moves the cursor one past the last byte.
        assert {:ok, 7} = LargeObject.seek(lob, 0, :end)
        assert {:ok, ""} == LargeObject.read(lob, 1)
      end)
    end

    test "succeeds seeking past end of object" do
      with_object("ABCDEFG", fn lob ->
        assert {:ok, 1000} = LargeObject.seek(lob, 1000, :start)
        assert {:ok, ""} == LargeObject.read(lob, 1)
        assert {:ok, 0} = LargeObject.seek(lob, -1000, :current)
        assert {:ok, "A"} == LargeObject.read(lob, 1)
      end)
    end

    test "fails seeking before beginning of object" do
      with_object("ABCDEFG", fn lob ->
        assert {:error, :invalid_offset} = LargeObject.seek(lob, -1, :current)
      end)
    end

    test "fails given invalid object" do
      with_object("ABCDEFG", fn lob ->
        :ok = LargeObject.remove(TestRepo, lob.oid)
        assert {:error, :not_found} = LargeObject.seek(lob, 3)
      end)
    end
  end

  describe "tell/1" do
    test "succeeds given valid object" do
      with_object("ABCDEF", fn lob ->
        assert {:ok, 0} = LargeObject.tell(lob)
      end)
    end

    test "returns new position after read" do
      with_object("ABCDEF", fn lob ->
        {:ok, _data} = LargeObject.read(lob, 3)
        assert {:ok, 3} = LargeObject.tell(lob)
      end)
    end

    test "returns new position after write" do
      with_object("ABCDEF", [mode: :write], fn lob ->
        :ok = LargeObject.write(lob, "12345")
        assert {:ok, 5} = LargeObject.tell(lob)
      end)
    end

    test "fails given invalid object" do
      with_object("ABCDEF", fn lob ->
        :ok = LargeObject.remove(TestRepo, lob.oid)
        assert {:error, :not_found} = LargeObject.tell(lob)
      end)
    end
  end

  describe "resize/2" do
    test "supports truncating to smaller size" do
      {:ok, oid} =
        with_object("ABCDEF", [mode: :write], fn lob ->
          assert :ok == LargeObject.resize(lob, 3)
        end)

      assert get_large_object!(oid) == "ABC"
    end

    test "supports extending to larger size" do
      {:ok, oid} =
        with_object("ABCDEF", [mode: :write], fn lob ->
          assert :ok == LargeObject.resize(lob, 10)
        end)

      assert get_large_object!(oid) == "ABCDEF" <> <<0, 0, 0, 0>>
    end

    test "supports truncating to zero bytes" do
      {:ok, oid} =
        with_object("ABCDEF", [mode: :write], fn lob ->
          assert :ok == LargeObject.resize(lob, 0)
        end)

      assert get_large_object!(oid) == ""
    end

    test "fails if given object is opened read-only" do
      with_object("ABCDEF", fn lob ->
        assert {:error, :read_only} = LargeObject.resize(lob, 3)
      end)
    end

    test "fails given invalid object" do
      with_object("ABCDEF", fn lob ->
        :ok = LargeObject.remove(TestRepo, lob.oid)
        assert {:error, :not_found} = LargeObject.resize(lob, 3)
      end)
    end
  end

  defp with_object(data, opts \\ [], fun) do
    oid = put_large_object!(data)

    TestRepo.transact(fn ->
      {:ok, lob} = LargeObject.open(TestRepo, oid, opts)
      fun.(lob)
      {:ok, lob.oid}
    end)
  end
end
