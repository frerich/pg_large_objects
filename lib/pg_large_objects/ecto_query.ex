defmodule PgLargeObjects.EctoQuery do
  @moduledoc """
  Extensions to Ecto's query DSL.

  Import this module to make various macros available wrapping the raw
  PostgreSQL API for dealing with large objects.

  This permits operating on large objects in bulk as part of SQL queries. For
  example

  ```elixir
  import Ecto.Query
  import PgLargeObjects.EctoQuery

  # Delete all data uploaded by a given user.
  from(upload in Upload,
    where: upload.user_id == ^user_id,
    select: lo_unlink(upload.object_id)
  ) |> Repo.all()
  ```

  See the PostgreSQL documentation at
  https://www.postgresql.org/docs/current/lo-interfaces.html for a discussion
  of these functions.
  """

  @doc """
  Create large object.

  See https://www.postgresql.org/docs/current/lo-interfaces.html#LO-CREATE for details.
  """
  defmacro lo_create(desired_oid \\ 0) do
    quote do
      fragment("lo_create(?)", unquote(desired_oid))
    end
  end

  @doc """
  Delete large object.

  See https://www.postgresql.org/docs/current/lo-interfaces.html#LO-UNLINK for details.
  """
  defmacro lo_unlink(oid) do
    quote do
      fragment("lo_unlink(?)", unquote(oid))
    end
  end

  @doc """
  Open large object for reading or writing.

  See https://www.postgresql.org/docs/current/lo-interfaces.html#LO-OPEN for details.
  """
  defmacro lo_open(oid, flags) do
    quote do
      fragment("lo_open(?, ?)", unquote(oid), unquote(flags))
    end
  end

  @doc """
  Close large object file descriptor.

  See https://www.postgresql.org/docs/current/lo-interfaces.html#LO-CLOSE for details.
  """
  defmacro lo_close(fd) do
    quote do
      fragment("lo_close(?)", unquote(fd))
    end
  end

  @doc """
  Write data to large object.

  See https://www.postgresql.org/docs/current/lo-interfaces.html#LO-WRITE for details.
  """
  defmacro lo_write(fd, data) do
    quote do
      fragment("lowrite(?, ?)", unquote(fd), unquote(data))
    end
  end

  @doc """
  Read data from large object.

  See https://www.postgresql.org/docs/current/lo-interfaces.html#LO-READ for details.
  """
  defmacro lo_read(fd, length \\ 1_048_576) do
    quote do
      fragment("loread(?, ?)", unquote(fd), unquote(length))
    end
  end

  @doc """
  Adjust read/write position in large object.

  See https://www.postgresql.org/docs/current/lo-interfaces.html#LO-SEEK for details.
  """
  defmacro lo_lseek64(fd, offset, whence) do
    quote do
      fragment("lo_lseek64(?, ?, ?)", unquote(fd), unquote(offset), unquote(whence))
    end
  end

  @doc """
  Get read/write position of large object.

  See https://www.postgresql.org/docs/current/lo-interfaces.html#LO-TELL for details.
  """
  defmacro lo_tell64(fd) do
    quote do
      fragment("lo_tell64(?)", unquote(fd))
    end
  end

  @doc """
  Truncate or expand large object.

  See https://www.postgresql.org/docs/current/lo-interfaces.html#LO-TRUNCATE for details.
  """
  defmacro lo_truncate64(fd, size) do
    quote do
      fragment("lo_truncate64(?, ?)", unquote(fd), unquote(size))
    end
  end
end
