defmodule PgLargeObjects do
  @moduledoc """
  Documentation for `PgLargeObjects`.
  """

  alias PgLargeObjects.LargeObject

  def import(stream, repo, opts \\ []) do
    opts = Keyword.validate!(opts, timeout: :timer.seconds(60))

    repo.transact(
      fn ->
        with {:ok, lob} <- LargeObject.create(repo) do
          stream
          |> Stream.into(lob)
          |> Stream.run()

          {:ok, lob.oid}
        end
      end,
      timeout: opts[:timeout]
    )
  end

  def export(oid, repo, stream, opts \\ []) do
    opts = Keyword.validate!(opts, timeout: :timer.seconds(60))

    repo.transact(
      fn ->
        with {:ok, lob} <- LargeObject.open(repo, oid) do
          lob
          |> Stream.into(stream)
          |> Stream.run()

          {:ok, lob.oid}
        end
      end,
      timeout: opts[:timeout]
    )
  end
end
