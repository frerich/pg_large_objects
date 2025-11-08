ExUnit.start()

{:ok, _repo} = PgLargeObjects.TestRepo.start_link(name: PgLargeObjects.TestRepo)

Ecto.Adapters.SQL.Sandbox.mode(PgLargeObjects.TestRepo, :manual)
