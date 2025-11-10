defmodule PgLargeObjects.LargeObject do
  @moduledoc """
  Low-level API for managing large objects.

  This module defines a structure `LargeObject` which represents a large object
  in a PostgreSQL database which was opened for reading or writing.

  The functions `create/2` and `open/3` create a new resp. open an existing
  large object given some object ID. These functions return a new `LargeObject`
  structure to which other functions such as `size/1` or `write/2` can be
  applied.

  > #### Transactions Required {: .info}
  >
  > All operations on `LargeObject` values *must* take place within a database
  > transactions since the internal handle managed by the structure is only
  > valid for the duration of a transaction.
  >
  > Any large object value will be closed automatically at the end of the
  > transaction.

  ## Streaming

  Since there is both an `Enumerable` as well as a `Collectable` implementation
  for this structure, `Enum` and `Stream` APIs can be used to interact with the
  object, e.g.

  ```elixir
  # Get 189th byte of object:
  Repo.transact(fn ->
    {:ok, lob} = LargeObject.open(Repo, object_id)
    {:ok, Enum.at(lob, 188)}
  end)

  # Stream object into a list of chunks:
  Repo.transact(fn ->
    {:ok, lob} = LargeObject.open(Repo, object_id)
    {:ok, Enum.to_list(lob)}
  end)
  ```
  """
  defstruct [:repo, :oid, :fd, :bufsize]

  alias PgLargeObjects.Bindings

  @type t :: %__MODULE__{
          repo: Ecto.Repo.t(),
          oid: pos_integer(),
          fd: non_neg_integer(),
          bufsize: non_neg_integer()
        }

  @doc false
  defguard is_pos_integer(value) when is_integer(value) and value > 0

  @doc false
  defguard is_non_neg_integer(value) when is_integer(value) and value >= 0

  @doc """
  Create (and open) a large object.

  Creates a new large object in the database `repo` with a random object ID,
  and opens it for reading or writing.

  The object will be closed automatically at the end of the transaction.

  ## Options

  * `:bufsize` - number of bytes to transfer at a time when streaming into/out
    of the object.
  * `:mode` - can be one of `:read`, `:write` or `:read_write` indicating
    whether to open the object for reading, writing, or both.

  ## Return value

  * `{:ok, lob}` where `lob` is `LargeObject` structure.
  """
  @spec create(Ecto.Repo.t(), keyword()) :: {:ok, t()}
  def create(repo, opts \\ []) when is_atom(repo) and is_list(opts) do
    opts = Keyword.validate!(opts, mode: :read_write, bufsize: 1_048_576)

    with {:ok, oid} <- Bindings.create(repo, 0) do
      open(repo, oid, opts)
    end
  end

  @doc """
  Open a large object for reading or writing.

  Opens an existing large object identified by the object identifier `oid` in
  the database `repo`.

  The object will be closed automatically at the end of the transaction.

  ## Options

  * `:bufsize` - number of bytes to transfer at a time when streaming into/out
    of the object. Defaults to 1MB.
  * `:mode` - can be one of `:read`, `:write` or `:read_write` indicating
    whether to open the object for reading, writing, or both. Defaults to `:read`.

  ## Return value

  * `{:ok, lob}` on success, where `lob` is `LargeObject` structure.
  * `{:error, :not_found}` if the given `oid` does not reference a large
    object.
  """
  @spec open(Ecto.Repo.t(), pos_integer(), keyword()) ::
          {:ok, t()} | {:error, :not_found}
  def open(repo, oid, opts \\ []) when is_atom(repo) and is_pos_integer(oid) and is_list(opts) do
    # https://www.postgresql.org/docs/current/lo-interfaces.html#LO-READ says
    #
    #   In practice, it's best to transfer data in chunks of at most a few
    #   megabytes anyway.
    #
    # So default to a buffer size of 1MB.
    opts = Keyword.validate!(opts, mode: :read, bufsize: 1_048_576)

    flags =
      case opts[:mode] do
        :read -> Bindings.constant(:inv_read)
        :write -> Bindings.constant(:inv_write)
        :read_write -> Bindings.constant(:inv_read) + Bindings.constant(:inv_write)
        mode -> raise ArgumentError, message: "invalid mode: #{mode}"
      end

    with {:ok, fd} <- Bindings.open(repo, oid, flags) do
      lob =
        %__MODULE__{
          repo: repo,
          oid: oid,
          fd: fd,
          bufsize: opts[:bufsize]
        }

      {:ok, lob}
    end
  end

  @doc """
  Remove a large object.

  Deletes a large object identified by `oid` from the database referenced by
  `repo`.

  ## Return value

  * `:ok` on success.
  * `{:error, :not_found}` if the given `oid` does not reference a large
    object.
  """
  @spec remove(Ecto.Repo.t(), pos_integer()) :: :ok | {:error, :not_found}
  def remove(repo, oid) when is_atom(repo) and is_pos_integer(oid) do
    Bindings.unlink(repo, oid)
  end

  @doc """
  Close a large object.

  Frees any database resources associated with the given object `lob`.

  Any large object descriptors that remain open at the end of a transaction
  will be closed automatically.

  ## Return value

  * `:ok` on success.
  * `{:error, :invalid_fd}` if the given large object no longer exists.
  """
  @spec close(t()) :: :ok | {:error, :invalid_fd}
  def close(%__MODULE__{} = lob) do
    Bindings.close(lob.repo, lob.fd)
  end

  @doc """
  Get the size of a large object.

  Calculates the size (in bytes) of the given large object `lob`.

  ## Return value

  * `{:ok, size}` on success, with `size` being the size of the object in
    bytes.
  * `{:error, :invalid_fd}` if the given large object no longer exists.
  """
  @spec size(t()) :: {:ok, non_neg_integer()} | {:error, :invalid_fd}
  def size(%__MODULE__{} = lob) do
    with {:ok, pos} <- tell(lob),
         {:ok, size} <- seek(lob, 0, :end),
         {:ok, ^pos} <- seek(lob, pos, :start) do
      {:ok, size}
    end
  end

  @doc """
  Write data to a large object.

  Writes the given binary `data` to the large object `lob`, starting at the
  current position in the object. May overwrite existing data, or extend the
  size of the object as needed. Advances the position in the large object by
  the number of bytes in `data`.

  The data is not chunked but transferred in one go. For large amounts of data,
  consider streaming data by leveraging the `Collectable` implementation, e.g.

  ```elixir
  Repo.transact(fn ->
      {:ok, lob} = LargeObject.open(Repo, object_id, [mode: :write])

      # Stream large file into the large object.
      File.stream!("/tmp/recording.ogg")
      |> Stream.into(lob)
      |> Stream.run()

      {:ok, nil}
  end)
  ```
  ## Return value

  * `:ok` on success
  * `{:error, :invalid_fd}` if the given large object no longer exists.
  * `{:error, :read_only}` if the given large object was not opened for writing.
  """
  @spec write(t(), binary()) :: :ok | {:error, :invalid_fd} | {:error, :read_only}
  def write(%__MODULE__{} = lob, data) when is_binary(data) do
    Bindings.write(lob.repo, lob.fd, data)
  end

  @doc """
  Read data from large object.

  Reads a `length` bytes of data from the given large object `lob`, starting at
  the current iosition in the object. Advanced the position by the number of
  bytes read, or until the end of file. The read position will not be advanced
  when the current position is beyond the end of the file.

  The data is not chunked but transferred in one go. For large amounts of data,
  do not pass a large `length` but instead consider streaming data by
  leveraging the `Enumerable` implementation, e.g.

  ```elixir
  Repo.transact(fn ->
      {:ok, lob} = LargeObject.open(Repo, object_id, [mode: :read])

      # Stream large object to local file.
      lob
      |> Stream.into(File.stream!("/tmp/recording.ogg"))
      |> Stream.run()

      {:ok, nil}
  end)
  ```

  ## Return value

  * `{:ok, data}` on success
  * `{:error, :invalid_fd}` if the given large object no longer exists.
  """
  @spec read(t(), non_neg_integer()) :: {:ok, binary()} | {:error, :invalid_fd}
  def read(%__MODULE__{} = lob, length) when is_non_neg_integer(length) do
    Bindings.read(lob.repo, lob.fd, length)
  end

  @doc """
  Set read/write position in large object.

  Modifies the current position within the large object to which `read/2` and
  `write/2` operations apply to `offset`.

  The `offset` value is interpreted depending on the `start` value, which can
  be one of three atoms:

  * `:start` - interpret `offset` as the number of bytes from the start of the
    object. The offset should be a non-negative value. Using the offset 0 moves
    the position to the first byte in the object.
  * `:current` - interpret `offset` as a value relative to the current
    position. The offset can be any integer. Using the offset 0 leaves the
    position unchanged.
  * `:end` - interpret `offset` as the number of bytes from the end of the
    object. The offset should be a non-positive value. Using the offset 0 moves
    the position to one byte *after* the object.

  The default `start` value is `:start`.

  It is possible to seek past the end of the object, but it is not permitted to
  seek before the beginning of the object.

  ## Return value

  * `{:ok, new_position}` on success
  * `{:error, :invalid_fd}` if the given large object no longer exists.
  """
  @spec seek(t(), integer(), :start | :current | :end) ::
          {:ok, non_neg_integer()} | {:error, :invalid_fd}
  def seek(%__MODULE__{} = lob, offset, start \\ :start)
      when is_integer(offset) and
             ((start == :start and offset >= 0) or start == :current or
                (start == :end and offset <= 0)) do
    whence =
      case start do
        :start -> Bindings.constant(:seek_set)
        :current -> Bindings.constant(:seek_cur)
        :end -> Bindings.constant(:seek_end)
      end

    Bindings.lseek64(lob.repo, lob.fd, offset, whence)
  end

  @doc """
  Get read/write position in large object.

  Returns the current position within the large object to which `read/2` and
  `write/2` operations apply.

  ## Return value

  * `{:ok, position}` on success
  * `{:error, :invalid_fd}` if the given large object no longer exists.
  """
  @spec tell(t()) :: {:ok, non_neg_integer()} | {:error, :invalid_fd}
  def tell(%__MODULE__{} = lob) do
    Bindings.tell64(lob.repo, lob.fd)
  end

  @doc """
  Resize large object.

  Truncates (or extends) the given large object `lob` such that it is `size`
  bytes in size.

  If `size` is larger than the current size of the object, the object will be
  extended with null bytes (<<0>>).

  ## Return value

  * `:ok` on success
  * `{:error, :invalid_fd}` if the given large object no longer exists.
  * `{:error, :read_only}` if the given large object was not opened for writing.
  """
  @spec resize(t(), non_neg_integer()) :: :ok | {:error, :invalid_fd}
  def resize(%__MODULE__{} = lob, size) when is_non_neg_integer(size) do
    Bindings.truncate64(lob.repo, lob.fd, size)
  end
end

defimpl Collectable, for: PgLargeObjects.LargeObject do
  alias PgLargeObjects.LargeObject

  def into(lob) do
    initial_acc = lob

    collector = fn
      lob, {:cont, data} ->
        LargeObject.write(lob, data)
        lob

      lob, :done ->
        LargeObject.close(lob)
        lob

      _lob, :halt ->
        :ok
    end

    {initial_acc, collector}
  end
end

defimpl Enumerable, for: PgLargeObjects.LargeObject do
  def reduce(lob, acc, fun) do
    start_fun = fn -> lob end

    next_fun = fn lob ->
      case PgLargeObjects.LargeObject.read(lob, lob.bufsize) do
        {:ok, ""} -> {:halt, lob}
        {:ok, data} -> {[data], lob}
      end
    end

    after_fun = fn lob ->
      PgLargeObjects.LargeObject.close(lob)
    end

    Stream.resource(start_fun, next_fun, after_fun).(acc, fun)
  end

  def count(lob) do
    with {:ok, size} <- PgLargeObjects.LargeObject.size(lob) do
      {:ok, ceil(size / lob.bufsize)}
    end
  end

  def member?(_lob, _element), do: {:error, __MODULE__}

  def slice(lob) do
    slicing_fun = fn
      start, length, 1 ->
        PgLargeObjects.LargeObject.seek(lob, start * lob.bufsize)

        for _ <- 0..(length - 1) do
          {:ok, data} = PgLargeObjects.LargeObject.read(lob, lob.bufsize)
          data
        end

      start, length, step ->
        for i <- 0..(length - 1)//step do
          PgLargeObjects.LargeObject.seek(lob, (start + i) * lob.bufsize)
          {:ok, data} = PgLargeObjects.LargeObject.read(lob, lob.bufsize)
          data
        end
    end

    {:ok, size} = count(lob)

    {:ok, size, slicing_fun}
  end
end
