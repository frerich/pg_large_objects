import Config

config :pg_large_objects, PgLargeObjects.TestRepo,
  database: "pg_large_objects_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox

config :pg_large_objects,
  ecto_repos: [PgLargeObjects.TestRepo]
