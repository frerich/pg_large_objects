# Considerations

The [PostgreSQL 7.1 documentation](https://www.postgresql.org/docs/7.1/largeobjects.html) explains:

> Originally, Postgres 4.2 supported three standard implementations of large objects

PostgreSQL 4.2 was released on Jun 30th, 1994. The large objects facility has
been around for a long time!

Yet, it is fairly unknown to many programmers - or considered too unwieldy to
use for productive usage. This is not by accident - there are various trade
offs to consider when deciding if large objects are a good mechanism for
storing large amounts of binary data.

This document attempts to collect and discuss some of these considerations. If
you feel there are other aspects to highlight, or if any of the items below
warrants further elaboration, please don't hesitate to submit a GitHub pull
request!

## Partial vs. Complete Data

The pg_large_objects library, at its highest level, exposes large objects as data
streams by defining appropriate implementations of the Enumerable (for reading)
and Collectable (for writing) behaviour. This is only possible by taking advantage
of the fact that large objects enable working with *partial* data. Objects can be
read and written in small chunks, and operations like
`PgLargeObjects.LargeObject.seek/2` enable accessing individual parts of a large
object without loading the entire data into memory.

If your application always only needs to work with the entire data as a whole,
and loading it into memory as a whole is possible and convenient, the
application might be better off with storing the data in a `bytea` column of
a table.

## Storage Costs

Storing large objects in a PostgreSQL database may greatly increase the amount
of disk space used by the database. This may be more expensive than other
mechanisms for storing large objects.

For example, the [AWS RDS
documentation](https://aws.amazon.com/rds/postgresql/pricing/) (RDS is Amazon's
managed database offering) explains that at the time of this writing, 1GB of
General Purpose storage for a in the us-east-1 region costs $0.115 per month
for a PostgreSQL database. The [AWS S3 documentation](https://aws.amazon.com/s3/pricing/) (S3 is Amazon's
object storage offering) documents, at the time of this writing, that storing
1GB of data in the us-east-1 region is a mere $0.023 per month!

I.e. when using Amazon cloud services in the us-east-1 region, storing data in
RDS is five times as expensive as storing it in S3. Depending on the amount of
data and your budget, this might be a significant difference.

Make sure to check the pricing (if applicable) for storage used by your
PostgreSQL database and consider the change in the decision whether to use
large objects or not.

## Backups

Given that large objects may quickly end up being the bulk of data stored in a
database, it's common to configure backups to exclude them from backups or only
include them in weekly backups or similar.

For example, the `pg_dump` command line utility features four related options:

```
frerich@Mac ~ % pg_dump --help
[..]
  -b, --large-objects          include large objects in dump
  --blobs                      (same as --large-objects, deprecated)
  -B, --no-large-objects       exclude large objects in dump
  --no-blobs                   (same as --no-large-objects, deprecated)
[..]
```

Consider your current backup mechanism and see if it's configured to include or
exclude large objects. Decide on the important of large objects for your use
case and include that in your decision on how often large objects should be
included in backups.
