defmodule PgLargeObjects.EctoQuery do
  @moduledoc """
  Extensions to Ecto's query DSL.
  """

  defmacro lo_create(desired_oid \\ 0) do
    quote do
      fragment("lo_create(?)", unquote(desired_oid))
    end
  end

  defmacro lo_unlink(oid) do
    quote do
      fragment("lo_unlink(?)", unquote(oid))
    end
  end

  defmacro lo_open(oid, flags) do
    quote do
      fragment("lo_open(?, ?)", unquote(oid), unquote(flags))
    end
  end

  defmacro lo_close(fd) do
    quote do
      fragment("lo_close(?)", unquote(fd))
    end
  end

  defmacro lo_write(fd, data) do
    quote do
      fragment("lowrite(?, ?)", unquote(fd), unquote(data))
    end
  end

  defmacro lo_read(fd, length \\ 1_048_576) do
    quote do
      fragment("loread(?, ?)", unquote(fd), unquote(length))
    end
  end

  defmacro lo_lseek64(fd, offset, whence) do
    quote do
      fragment("lo_lseek64(?, ?, ?)", unquote(fd), unquote(offset), unquote(whence))
    end
  end

  defmacro lo_tell64(fd) do
    quote do
      fragment("lo_tell64(?)", unquote(fd))
    end
  end

  defmacro lo_truncate64(fd, size) do
    quote do
      fragment("lo_truncate64(?, ?)", unquote(fd), unquote(size))
    end
  end
end
