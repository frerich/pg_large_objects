defmodule PgLargeObjects.Repo do
  @moduledoc """
  Extension API for Ecto.Repo
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      def import_large_object(stream, opts \\ []) do
        PgLargeObjects.import(stream, __MODULE__, opts)
      end

      def export_large_object(oid, stream, opts \\ []) do
        PgLargeObjects.export(oid, __MODULE__, stream, opts)
      end

      def create_large_object(opts \\ []) do
        PgLargeObjects.LargeObject.create(__MODULE__, opts)
      end

      def open_large_object(oid, opts \\ []) do
        PgLargeObjects.LargeObject.open(__MODULE__, oid, opts)
      end

      def remove_large_object(oid) do
        PgLargeObjects.LargeObject.remove(__MODULE__, oid)
      end
    end
  end
end
