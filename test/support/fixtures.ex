defmodule PgLargeObjects.Fixtures do
  @moduledoc """
  Functionality for setting up test fixtures.
  """

  alias PgLargeObjects.Bindings
  alias PgLargeObjects.TestRepo

  def put_large_object!(data) do
    {:ok, oid} = Bindings.create(TestRepo, 0)
    {:ok, fd} = Bindings.open(TestRepo, oid, Bindings.constant(:inv_write))
    :ok = Bindings.write(TestRepo, fd, data)
    :ok = Bindings.close(TestRepo, fd)
    oid
  end

  def get_large_object!(oid) do
    {:ok, fd} = Bindings.open(TestRepo, oid, Bindings.constant(:inv_read))
    {:ok, data} = Bindings.read(TestRepo, fd, 1_048_576)
    :ok = Bindings.close(TestRepo, fd)
    data
  end
end
