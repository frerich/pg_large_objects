defmodule PgLargeObjects do
  @moduledoc """
  High-level API for managing large objects.

  This exposes commonly-used functionality for streaming data into or out of
  the database using the functions `import/3` and `export/3`.

  See `PgLargeObjects.LargeObject` for a lower-level API which exposes more
  functionality for individual large objects.
  """

  alias PgLargeObjects.LargeObject

  @doc """
  Import data into large object.

  This imports the data in `data` into a new large object in the database
  referenced by `repo`.

  `data` can either be a binary which will be uploaded in multiple chunks, or
  an arbitrary `Enumerable`.

  This function needs to be executed as part of a transaction.

  ## Options

  * `:bufsize` - number of bytes to transfer per chunk. Defaults to 65536 bytes.

  ## Return value

  * `{:ok, object_id}` in case of success.
  """
  @spec import(Ecto.Repo.t() | pid(), binary() | Enumerable.t(), keyword()) ::
          {:ok, pos_integer()}
  def import(repo, data, opts \\ []) when (is_atom(repo) or is_pid(repo)) and is_list(opts) do
    opts = Keyword.validate!(opts, bufsize: 65_536)

    case data do
      binary when is_binary(binary) ->
        {:ok, buffer} = StringIO.open(binary, encoding: :latin1)
        result = import(repo, IO.binstream(buffer, opts[:bufsize]), opts)
        StringIO.close(buffer)
        result

      enumerable ->
        with {:ok, lob} <- LargeObject.create(repo) do
          enumerable
          |> Stream.into(lob)
          |> Stream.run()

          {:ok, lob.oid}
        end
    end
  end

  @doc """
  Export data out of large object.

  This exports the data in the large object referenced by the object ID `oid`.
  Depending on the `:into` option, the data is returned a single binary or fed
  into a given `Collectable`.

  This function needs to be executed as part of a transaction.

  ## Options

  * `:bufsize` - number of bytes to transfer per chunk. Defaults to 65536 bytes.
  * `:into` - can be `nil` to download all data into a single binary or any
    `Collectable`. Defaults to `nil`.

  ## Return value

  * `:ok` in case the `:into` option references a `Collectable`.
  * `{:ok, data}` in case the `:into` option is `nil`
  * `{:error, :invalid_oid}` in case there is no large object with the given
    `oid`.
  """
  @spec export(Ecto.Repo.t() | pid(), pos_integer(), keyword()) ::
          :ok | {:ok, binary()} | {:error, :invalid_oid}
  def export(repo, oid, opts \\ [])
      when (is_atom(repo) or is_pid(repo)) and is_integer(oid) and oid > 0 and is_list(opts) do
    opts = Keyword.validate!(opts, [:into, bufsize: 65_536])

    case opts[:into] do
      nil ->
        {:ok, buffer} = StringIO.open("", encoding: :latin1)

        result =
          with :ok <- export(repo, oid, into: IO.binstream(buffer, opts[:bufsize])) do
            {_input, output} = StringIO.contents(buffer)
            {:ok, output}
          end

        StringIO.close(buffer)

        result

      collectable ->
        with {:ok, lob} <- LargeObject.open(repo, oid, bufsize: opts[:bufsize]) do
          lob
          |> Stream.into(collectable)
          |> Stream.run()

          :ok
        end
    end
  end
end
