# Run via 'MIX_ENV=test mix run bench/export.exs'
#
{:ok, _pid} = PgLargeObjects.TestRepo.start_link(name: PgLargeObjects.TestRepo)

do_import = fn input, bufsize ->
  PgLargeObjects.TestRepo.transact(fn ->
    PgLargeObjects.import(PgLargeObjects.TestRepo, input, bufsize: bufsize)
    PgLargeObjects.TestRepo.rollback(nil)
  end)
end

Benchee.run(
  %{
    "bufsize=8192" => fn input -> do_import.(input, 8_192) end,
    "bufsize=65536" => fn input -> do_import.(input, 65_536) end,
    "bufsize=1048576" => fn input -> do_import.(input, 1_048_576) end
  },
  inputs: %{
    "small" => String.duplicate("data", 100),
    "medium" => String.duplicate("data", 100_000),
    "large" => String.duplicate("data", 100_000_000)
  }
)

