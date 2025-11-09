defmodule PgLargeObjects.Repo do
  @moduledoc """
  Extension API for Ecto.Repo.

  This exposes convenience APIs on an application's Ecto repository module such
  that explicitly passing the name of the repository to different APIs is no
  longer necessary.

  The module is meant to be referenced via `use`, as in:

  ```elixir
  defmodule MyApp.Repo do
    use Ecto.Repo,
      otp_app: :my_app,
      adapter: Ecto.Adapters.Postgres

    use PgLargeObjects.Repo
  end
  ```

  Doing so causes the following convenience functions to be defined on the repository module:

  * `import_large_object(data, opts)` for importing data into a large object
    using `PgLargeObjects.import/3`.
  * `export_large_object(oid, opts)` for exporting data from a large object
    using `PgLargeObjects.export/3`.
  * `create_large_object/1` for creating a new large object using
    `PgLargeObjects.LargeObject.create/2`.
  * `open_large_object/1` for opening an existing large object using
    `PgLargeObjects.LargeObject.open/3`.
  * `remove_large_object/1` for removing a large object using
    `PgLargeObjects.LargeObject.remove/2`.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @doc """
      Import data into large object.

      See `PgLargeObjects.import/3` for documentation.
      """
      def import_large_object(data, opts \\ []) do
        PgLargeObjects.import(__MODULE__, data, opts)
      end

      @doc """
      Export data from large object.

      See `PgLargeObjects.export/3` for documentation.
      """
      def export_large_object(oid, opts \\ []) do
        PgLargeObjects.export(__MODULE__, oid, opts)
      end

      @doc """
      Create (and open) a large object.

      See `PgLargeObjects.LargeObject.create/2` for documentation.
      """
      def create_large_object(opts \\ []) do
        PgLargeObjects.LargeObject.create(__MODULE__, opts)
      end

      @doc """
      Open a large object for reading or writing.

      See `PgLargeObjects.LargeObject.open/3` for documentation.
      """
      def open_large_object(oid, opts \\ []) do
        PgLargeObjects.LargeObject.open(__MODULE__, oid, opts)
      end

      @doc """
      Remove a large object.

      See `PgLargeObjects.LargeObject.remove/2` for documentation.
      """
      def remove_large_object(oid) do
        PgLargeObjects.LargeObject.remove(__MODULE__, oid)
      end
    end
  end
end
