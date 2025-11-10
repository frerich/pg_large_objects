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

  Furthermore, a type `t` is defined in the current module. In case this is not
  desirable, e.g. because a type is already defined, pass the option
  `omit_typespec: true`.
  """

  @doc false
  defmacro __using__(opts) do
    opts = Keyword.validate!(opts, omit_typespec: false)

    quote do
      if not unquote(opts[:omit_typespec]) do
        @type t :: %{}
      end

      @doc """
      Import data into large object.

      See `PgLargeObjects.import/3` for documentation.
      """
      @spec import_large_object(binary() | Enumerable.t(), keyword()) :: {:ok, pos_integer()}
      def import_large_object(data, opts \\ []) do
        PgLargeObjects.import(__MODULE__, data, opts)
      end

      @doc """
      Export data from large object.

      See `PgLargeObjects.export/3` for documentation.
      """
      @spec export_large_object(pos_integer(), keyword()) ::
              {:ok, binary()} | {:ok, :ok} | {:error, :invalid_oid}
      def export_large_object(oid, opts \\ []) do
        PgLargeObjects.export(__MODULE__, oid, opts)
      end

      @doc """
      Create (and open) a large object.

      See `PgLargeObjects.LargeObject.create/2` for documentation.
      """
      @spec create_large_object(keyword()) :: {:ok, PgLargeObjects.LargeObject.t()}
      def create_large_object(opts \\ []) do
        PgLargeObjects.LargeObject.create(__MODULE__, opts)
      end

      @doc """
      Open a large object for reading or writing.

      See `PgLargeObjects.LargeObject.open/3` for documentation.
      """
      @spec open_large_object(pos_integer(), keyword()) ::
              {:ok, PgLargeObjects.LargeObject.t()} | {:error, :invalid_oid}
      def open_large_object(oid, opts \\ []) do
        PgLargeObjects.LargeObject.open(__MODULE__, oid, opts)
      end

      @doc """
      Remove a large object.

      See `PgLargeObjects.LargeObject.remove/2` for documentation.
      """
      @spec remove_large_object(pos_integer()) :: :ok | {:error, :invalid_oid}
      def remove_large_object(oid) do
        PgLargeObjects.LargeObject.remove(__MODULE__, oid)
      end
    end
  end
end
