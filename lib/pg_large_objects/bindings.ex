defmodule PgLargeObjects.Bindings do
  @moduledoc """
  Low-level bindings to PostgreSQL Large Object API.
  """

  # See https://www.postgresql.org/docs/current/largeobjects.html

  # Constants taken from libpq/libpq-fs.h
  @inv_read 0x00040000
  @inv_write 0x00020000
  @seek_set 0
  @seek_cur 1
  @seek_end 2

  defguard is_pos_integer(value) when is_integer(value) and value > 0
  defguard is_non_neg_integer(value) when is_integer(value) and value >= 0
  defguard is_repo(value) when is_atom(value) or is_pid(value)

  def create(repo, desired_oid)
      when is_repo(repo) and is_non_neg_integer(desired_oid) do
    case repo.query("SELECT lo_create($1)", [desired_oid]) do
      {:ok, %{rows: [[oid]]}} -> {:ok, oid}
      {:error, %{postgres: %{code: :unique_violation}}} -> {:error, :already_exists}
    end
  end

  def unlink(repo, oid) when is_repo(repo) and is_pos_integer(oid) do
    case repo.query("SELECT lo_unlink($1)", [oid]) do
      {:ok, _} -> :ok
      {:error, %{postgres: %{code: :undefined_object}}} -> {:error, :invalid_oid}
    end
  end

  def open(repo, oid, flags)
      when is_repo(repo) and is_pos_integer(oid) and is_non_neg_integer(flags) do
    case repo.query("SELECT lo_open($1, $2)", [oid, flags]) do
      {:ok, %{rows: [[fd]]}} ->
        {:ok, fd}

      {:error, %{postgres: %{code: :undefined_object}}} ->
        {:error, :invalid_oid}
    end
  end

  def close(repo, fd) when is_repo(repo) and is_non_neg_integer(fd) do
    case repo.query("SELECT lo_close($1)", [fd]) do
      {:ok, _} -> :ok
      {:error, %{postgres: %{code: :undefined_object}}} -> {:error, :invalid_fd}
    end
  end

  def write(repo, fd, data) when is_repo(repo) and is_non_neg_integer(fd) and is_binary(data) do
    case repo.query("SELECT lowrite($1, $2)", [fd, data]) do
      {:ok, _} -> :ok
      {:error, %{postgres: %{code: :object_not_in_prerequisite_state}}} -> {:error, :read_only}
      {:error, %{postgres: %{code: :undefined_object}}} -> {:error, :invalid_fd}
    end
  end

  def read(repo, fd, length)
      when is_repo(repo) and is_non_neg_integer(fd) and is_non_neg_integer(length) do
    case repo.query("SELECT loread($1, $2)", [fd, length]) do
      {:ok, %{rows: [[data]]}} ->
        {:ok, data}

      {:error, %{postgres: %{code: :undefined_object}}} ->
        {:error, :invalid_fd}
    end
  end

  def lseek64(repo, fd, offset, whence)
      when is_repo(repo) and is_non_neg_integer(fd) and is_non_neg_integer(offset) and
             whence in [@seek_set, @seek_cur, @seek_end] do
    case repo.query("SELECT lo_lseek64($1, $2, $3)", [fd, offset, whence]) do
      {:ok, %{rows: [[position]]}} ->
        {:ok, position}

      {:error, %{postgres: %{code: :undefined_object}}} ->
        {:error, :invalid_fd}
    end
  end

  def tell64(repo, fd) when is_repo(repo) and is_non_neg_integer(fd) do
    case repo.query("SELECT lo_tell64($1)", [fd]) do
      {:ok, %{rows: [[position]]}} ->
        {:ok, position}

      {:error, %{postgres: %{code: :undefined_object}}} ->
        {:error, :invalid_fd}
    end
  end

  def truncate64(repo, fd, size)
      when is_repo(repo) and is_non_neg_integer(fd) and is_non_neg_integer(size) do
    case repo.query(repo, "SELECT lo_truncate64($1, $2)", [fd, size]) do
      {:ok, %{rows: [[size]]}} ->
        {:ok, size}

      {:error, %{postgres: %{code: :undefined_object}}} ->
        {:error, :invalid_fd}
    end
  end

  def constant(:inv_read), do: @inv_read
  def constant(:inv_write), do: @inv_write
  def constant(:seek_set), do: @seek_set
  def constant(:seek_cur), do: @seek_cur
  def constant(:seek_end), do: @seek_end
end
