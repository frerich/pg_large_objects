defmodule PgLargeObjects.UploadWriterTest do
  use PgLargeObjects.ConnCase, async: false

  alias Ecto.Adapters.SQL.Sandbox

  defmodule PhotoUploadForm do
    use Phoenix.LiveView

    def mount(_params, session, socket) do
      %{"test_pid" => test_pid} = session

      {:ok,
       socket
       |> Phoenix.Component.assign(:test_pid, test_pid)
       |> allow_upload(:photo,
         accept: ~w(.jpg .jpeg),
         writer: fn _name, _entry, _socket ->
           {PgLargeObjects.UploadWriter, repo: PgLargeObjects.TestRepo}
         end
       )}
    end

    def render(assigns) do
      ~H"""
      <form id="upload-form" phx-change="validate" phx-submit="save">
        <.live_file_input upload={@uploads.photo} />
        <button type="submit">Upload</button>
      </form>
      """
    end

    def handle_event("save", _params, socket) do
      %{test_pid: test_pid} = socket.assigns

      [object_id] =
        consume_uploaded_entries(socket, :photo, fn meta, _entry ->
          %{object_id: object_id} = meta
          {:ok, object_id}
        end)

      send(test_pid, {:large_object_uploaded, object_id})

      {:noreply, socket}
    end
  end

  setup do
    # Enable shared mode so that LiveView processes (which run the
    # `UploadWriter` code) can access the repo.
    Sandbox.mode(PgLargeObjects.TestRepo, {:shared, self()})
    :ok
  end

  test "works", %{conn: conn} do
    {:ok, view, _html} =
      live_isolated(conn, __MODULE__.PhotoUploadForm, session: %{"test_pid" => self()})

    fake_data = :crypto.strong_rand_bytes(1_048_576)

    view
    |> file_input("#upload-form", :photo, [
      %{
        last_modified: 1_594_171_879_000,
        name: "photo.jpeg",
        content: fake_data,
        size: byte_size(fake_data),
        type: "image/jpeg"
      }
    ])
    |> render_upload("photo.jpeg")

    view
    |> element("#upload-form")
    |> render_submit(%{})

    receive do
      {:large_object_uploaded, object_id} ->
        assert get_large_object!(object_id) == fake_data
    end
  end
end
