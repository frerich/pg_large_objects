if Code.ensure_loaded?(Phoenix.LiveView.UploadWriter) do
  defmodule PgLargeObjects.UploadWriter do
    @moduledoc """
    LiveView UploadWriter streaming data to Postgres large object.

    This module can be used with `Phoenix.LiveView.allow_upload/3` to specify
    that file uploads by clients should be streamed straight to large objects in
    the database. Pass the `:repo` option in the second element of the tuple
    returned by the function passed to `:writer` to indicate which database the
    object should be created in, e.g.:

    ```elixir
    socket
    |> allow_upload(:photo,
      accept: :any,
      writer: fn _name, _entry, _socket ->
        {PgLargeObjects.UploadWriter, repo: MyApp.Repo}
      end
    )
    ```

    The object ID of the uploaded file is available in the meta data available
    to the callback given to `Phoenix.LiveView.consume_uploaded_entries/3`:

    ```elixir
    consume_uploaded_entries(socket, :photo, fn meta, _entry ->
      %{object_id: object_id} = meta

      # Store `object_id` in database to retain handle to uploaded data.

      {:ok, nil}
    end)
    ```

    See `Phoenix.LiveView.UploadWriter` for further information.
    """

    @behaviour Phoenix.LiveView.UploadWriter

    alias PgLargeObjects.LargeObject

    @impl Phoenix.LiveView.UploadWriter
    def init(opts) do
      repo = Keyword.fetch!(opts, :repo)

      with {:ok, object} <- LargeObject.create(repo) do
        {:ok, %{object_id: object.oid, repo: repo}}
      end
    end

    @impl Phoenix.LiveView.UploadWriter
    def meta(state), do: state

    @impl Phoenix.LiveView.UploadWriter
    def write_chunk(data, state) do
      %{object_id: object_id, repo: repo} = state

      result =
        repo.transaction(fn ->
          result =
            with {:ok, object} <- LargeObject.open(repo, object_id, mode: :append),
                 :ok <- LargeObject.write(object, data) do
              LargeObject.close(object)
            end

          case result do
            :ok -> state
            {:error, error} -> repo.rollback(error)
          end
        end)

      case result do
        {:ok, state} -> {:ok, state}
        {:error, error} -> {:error, error, state}
      end
    end

    @impl Phoenix.LiveView.UploadWriter
    def close(state, _reason) do
      {:ok, state}
    end
  end
end
