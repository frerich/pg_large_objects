defmodule PgLargeObjects.LargeObject do
  @moduledoc """
  A PostgresSQL Large Object
  """
  defstruct [:repo, :oid, :fd, :bufsize]

  alias PgLargeObjects.Bindings

  defguard is_pos_integer(value) when is_integer(value) and value > 0
  defguard is_non_neg_integer(value) when is_integer(value) and value >= 0
  defguardp is_repo(value) when is_atom(value) or is_pid(value)

  def create(repo, opts \\ []) when is_repo(repo) and is_list(opts) do
    opts = Keyword.validate!(opts, mode: :read_write, bufsize: 1_048_576)

    with {:ok, oid} <- Bindings.create(repo, 0) do
      open(repo, oid, opts)
    end
  end

  def open(repo, oid, opts \\ []) when is_repo(repo) and is_pos_integer(oid) and is_list(opts) do
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

  def remove(repo, oid) when is_repo(repo) and is_pos_integer(oid) do
    Bindings.unlink(repo, oid)
  end

  def close(%__MODULE__{} = lob) do
    Bindings.close(lob.repo, lob.fd)
  end

  def size(%__MODULE__{} = lob) do
    with {:ok, pos} <- tell(lob),
         {:ok, size} <- seek(lob, 0, :end),
         {:ok, ^pos} <- seek(lob, pos, :start) do
      {:ok, size}
    end
  end

  def write(%__MODULE__{} = lob, data) when is_binary(data) do
    Bindings.write(lob.repo, lob.fd, data)
  end

  def read(%__MODULE__{} = lob), do: read(lob, lob.bufsize)

  def read(%__MODULE__{} = lob, length) when is_non_neg_integer(length) do
    Bindings.read(lob.repo, lob.fd, length)
  end

  def seek(%__MODULE__{} = lob, offset, start \\ :start)
      when is_non_neg_integer(offset) and start in [:start, :current, :end] do
    whence =
      case start do
        :start -> Bindings.constant(:seek_set)
        :current -> Bindings.constant(:seek_cur)
        :end -> Bindings.constant(:seek_end)
      end

    Bindings.lseek64(lob.repo, lob.fd, offset, whence)
  end

  def tell(%__MODULE__{} = lob) do
    Bindings.tell64(lob.repo, lob.fd)
  end

  def resize(%__MODULE__{} = lob, size) when is_non_neg_integer(size) do
    Bindings.truncate64(lob.repo, lob.fd, lob.bufsize)
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
      case PgLargeObjects.LargeObject.read(lob) do
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
          {:ok, data} = PgLargeObjects.LargeObject.read(lob)
          data
        end

      start, length, step ->
        for i <- 0..(length - 1)//step do
          PgLargeObjects.LargeObject.seek(lob, (start + i) * lob.bufsize)
          {:ok, data} = PgLargeObjects.LargeObject.read(lob)
          data
        end
    end

    {:ok, size} = count(lob)

    {:ok, size, slicing_fun}
  end
end
