# PgLargeObjects

An Elixir library for working with [large
objects](https://www.postgresql.org/docs/current/largeobjects.html) in
PostgreSQL databases.

## Features

* Easy and memory-efficient streaming of large amounts of data (up to 4TB) using `PgLargeObjects` high-level API.
* Random-access reads and writes to data objects via low-level `PgLargeObjects.LargeObject` API.
* Extensions to Ecto query DSL for interacting with large objects as part of
  Ecto queries.

## Why Use Large Objects?

An application wishing to store larger amounts of data typically has two options for doing so:

1. A new column on some table can be introduced; Postgres features a `bytea` type for this purpose. This is easy to implement but suffers from requiring to hold the complete data in memory when reading or writing, something which may not be viable beyond a few dozen megabytes. Efficient streaming or random-access operations are not practical.
2. A separate cloud storage (e.g. AWS S3) could be used. This permits streaming but requires complicating the tech stack by depending on a new service. Bridging the two systems (e.g. ‘Delete all uploads for a given user ID’) requires Elixir support.

PostgreSQL features a ‘large objects’ facility which enables efficient streaming access to large (up to 4TB) files. This solves these problems:

1. Unlike values in table columns, large objects can be streamed into/out of the database and permit random access operations.
2. Unlike e.g. S3, no new technology is needed. Large objects live side-by-side with the tables referencing them, operations like ‘Delete all uploads for a given user ID’ are just one `SELECT` statement.

## Installation

Install the package by adding `pg_large_objects` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:pg_large_objects, "~> 0.1"}
  ]
end
```

Optional, but recommended: include `PgLargeObjects.Repo` in your `Ecto.Repo`
module to define convenience API:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use PgLargeObjects.Repo
end
```

## Database Configuration

Large objects are referenced by object IDs, modelled using the `oid` type in
PostgreSQL. `Ecto.Migration` has support for this type built-in, e.g.

```elixir
defmodule MyApp.Repo.Migrations.CreateUploadsTable do
  use Ecto.Migration

  def change do
    create table(:uploads) do
      add :user_id, references(:users), null: false
      add :object_id, :oid, null: false

      timestamps()
    end
  end
end
```

In the Ecto schema, use plain `:integer` fields for object IDs:

```elixir
defmodule MyApp.Upload do
  use Ecto.Schema

  schema "uploads" do
    belongs_to :user, MyApp.User
    field :object_id, :integer

    timestamps()
  end
end
```

## Usage

Use the high-level APIs `PgLargeObjects.import/3` and `PgLargeObjects.export/3`
(exposed as `import_large_object/2` and `export_large_object/2` on the
 applications' repository module) for importing data into or exporting data out
of the database:

```elixir
# Import binary into large object
{:ok, object_id} = Repo.import_large_object("My payload.")

# Stream data into large object
{:ok, object_id} =
  "/tmp/recording.mov"
  |> File.stream!()
  |> Repo.import_large_object()

# ...store object_id somewhere to maintain reference to data.
```

```elixir
# Export binary from large object
{:ok, data} = Repo.export_large_object(object_id)

# Stream data of large object into Collectable
stream = File.stream!("/tmp/recording.mov")
:ok = Repo.export_large_object(object_id, into: stream)
```

Use the lower-level API in `PgLargeObjects.LargeObject` to interact with
individual object files on a more granular level.

## License

Copyright (c) 2025 Frerich Raabe.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
