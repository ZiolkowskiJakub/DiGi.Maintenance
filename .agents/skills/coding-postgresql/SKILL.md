---
name: coding-postgresql
description: Use when designing database schemas or executing queries with Npgsql / PostgreSQL in DiGi solutions - Classes/Converter/ architecture, NULLS NOT DISTINCT composite unique indexes for nullable columns, query batching (batchSize = 1000, ANY(@array)), commandTimeout parameter standard, and connection asset isolation in user files/.
---

# AI Guidelines: PostgreSQL & Npgsql Development

**Environment:** PostgreSQL 15+ / 18, Npgsql, .NET 9.0+, C# 10+.  
**Domain:** Database persistence, GIS relational data, table partitioning, and bulk data processing (`DiGi.PostgreSQL`, `DiGi.GIS.PostgreSQL`).

---

## 1. Architecture & Converter Pattern

Data models are separated from database persistence logic using static partial class converters and extension methods.

### Structure Breakdown
- **Converters (`/Classes/Converter/`):** Class-specific converters (e.g. `BuildingPostgreSQLConverter`, `TablePostgreSQLConverter`, `OrtoDatasPostgreSQLConverter`) manage mapping between DiGi model objects and PostgreSQL tables/views.
- **Schema Creation (`/Create/TableAsync.cs`):** Static asynchronous methods responsible for DDL execution (table creation, partitioning definitions, index generation). All DDL commands should be idempotent (`IF NOT EXISTS`).
- **Queries (`/Query/`):** Read-only data access methods extending `NpgsqlConnection?` (e.g. `PullAsync`, `Building2DsAsync`).
- **Modifications (`/Modify/`):** Write/update/delete operations extending `NpgsqlConnection?` or `Table<TColumn, TRow>` (e.g. `PushAsync`, `UpdateAsync`, `DeleteAsync`).
- **Background Tasks (`/Classes/BackgroundTask/`):** Long-running data synchronization and migration tasks inheriting from `ReportableBackgroundTask`.

---

## 2. Composite Unique Constraints & `NULLS NOT DISTINCT` (PostgreSQL 15+)

### The Problem with Nullable Columns in Unique Indexes
In standard SQL and default PostgreSQL behavior, `NULL` values are treated as distinct (`NULL != NULL`). If a composite unique index includes nullable columns (e.g. `(county_id, reference, lod, year)` where `lod` or `year` can be `NULL`):
- PostgreSQL allows multiple rows with identical `county_id` and `reference` whenever `lod` or `year` is `NULL`.
- An `INSERT ... ON CONFLICT (county_id, reference, lod, year) DO UPDATE ...` fails to match the existing row containing `NULL` values, causing duplicate insertions or constraint violations.

### The Rule
For any unique index or constraint on a composite key that contains nullable columns, always specify **`NULLS NOT DISTINCT`**:

```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_building_ref_lod_year
ON building (county_id, reference, lod, year) NULLS NOT DISTINCT;
```

### Benefits & Mechanics
1. **Deterministic UPSERT:** `ON CONFLICT (county_id, reference, lod, year)` properly matches rows where one or more fields are `NULL` and updates the existing record.
2. **Performance:** Index lookup and traversal speed is identical to standard B-Tree indexes ($O(\log N)$).

---

## 3. Query Performance, Batching & Timeout Prevention (`Error 57014`)

### Prohibition of Per-Item Loop Queries
> **NEVER execute individual SQL queries inside a loop over a collection.**

Executing queries inside a loop (e.g. 50,000 separate `SELECT` commands for each building reference) causes connection pool starvation, severe latency, and statement cancellation exceptions:
`Npgsql.PostgresException (0x80004005): 57014: cancelling statement due to user request` (Npgsql command timeout).

### Query Batching Pattern
- **Chunked Lookups:** Batch lookups in configurable chunks (defaulting to `int batchSize = 1000`).
- **Array Parameter Matching:** Use PostgreSQL `ANY(@arrayParameter)` rather than building dynamic `IN (...)` SQL strings:

```csharp
using Npgsql;
using NpgsqlTypes;

public static async Task<List<Building2D>> Building2DsByReferencesAsync(
    NpgsqlConnection? npgsqlConnection,
    IEnumerable<string>? references,
    int batchSize = 1000,
    int commandTimeout = 30,
    CancellationToken cancellationToken = default)
{
    if (npgsqlConnection == null || references == null)
    {
        return [];
    }

    List<Building2D> building2Ds_Result = [];
    List<string> references_List = references.Where(r => !string.IsNullOrWhiteSpace(r)).ToList();

    for (int i = 0; i < references_List.Count; i += batchSize)
    {
        cancellationToken.ThrowIfCancellationRequested();

        string[] referenceChunk = references_List.Skip(i).Take(batchSize).ToArray();

        const string sql = @"
            SELECT id, county_id, reference, geometry_wkt
            FROM building_2d
            WHERE reference = ANY(@references);";

        await using NpgsqlCommand npgsqlCommand = new(sql, npgsqlConnection);
        npgsqlCommand.CommandTimeout = commandTimeout;
        npgsqlCommand.Parameters.Add(new NpgsqlParameter("references", NpgsqlDbType.Array | NpgsqlDbType.Text) { Value = referenceChunk });

        await using NpgsqlDataReader reader = await npgsqlCommand.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            // Map record to Building2D
        }
    }

    return building2Ds_Result;
}
```

### Standard `commandTimeout` Parameter
- All methods executing database queries, bulk updates, table creation, or analytical aggregations must expose an optional `int commandTimeout = 30` parameter (or higher, e.g. 60/120 for bulk operations).
- Assign `npgsqlCommand.CommandTimeout = commandTimeout;` before execution.
- Order parameters with `commandTimeout` placed before `CancellationToken` (per rule CA1068).

---

## 4. Resource Management & Async Lifecycle

1. **`await using` Disposal:** Always wrap `NpgsqlCommand`, `NpgsqlDataReader`, and `NpgsqlTransaction` in `await using` blocks to ensure unmanaged database resources and active readers are released immediately:
   ```csharp
   await using NpgsqlCommand npgsqlCommand = new(query, npgsqlConnection);
   npgsqlCommand.CommandTimeout = commandTimeout;
   await using NpgsqlDataReader reader = await npgsqlCommand.ExecuteReaderAsync(cancellationToken);
   ```
2. **Parameterized Queries:** Always parameterize input **values** using `NpgsqlParameter` or `Parameters.AddWithValue`. Never concatenate user input into raw SQL strings — it prevents SQL injection and lets PostgreSQL cache the query plan. An **identifier** (a column or table name) cannot be a parameter and needs the whitelist treatment in §5 instead.
3. **`CancellationToken` Threading:** Always pass `cancellationToken` to all asynchronous Npgsql operations (`ExecuteNonQueryAsync`, `ExecuteReaderAsync`, `ExecuteScalarAsync`, `ReadAsync`).

---

## 5. Dynamic SQL Identifiers (Column and Table Names)

A value can be a parameter. **An identifier cannot** — `@column` is not valid syntax for a column
name, so a query that names a column chosen at runtime is forced to build that name into the
statement text. "Never concatenate" is not a rule anyone can follow there, which is how this was got
wrong.

The rule that can be followed:

> **Resolve a dynamic identifier against the stored column list, reject anything not on it, and
> double-quote what survives.** The list is the guard, because nothing else can be.

### The reference implementation

`TablePostgreSQLConverter.GetUniqueValuesAsync` in `DiGi.PostgreSQL.Table` does this correctly and is
what to copy — or better, to delegate to:

```csharp
// Column whitelist validation to prevent SQL injection (target column + every filter column)
HashSet<string> uniqueIds = [columnUniqueId];
filterGroup?.CollectColumnUniqueIds(uniqueIds);

List<UColumn>? columns_Existing = await GetColumnsByUniqueIdsAsync(npgsqlConnection, uniqueIds);
if (columns_Existing is null || !columns_Existing.Exists(x => x?.UniqueId() == columnUniqueId))
{
    return null;
}

string commandQuery = $@"
    SELECT DISTINCT ""{columnUniqueId}""
    FROM ""{TableName}""
    WHERE {stringBuilder_Where}
    ORDER BY ""{columnUniqueId}""";
```

Note that it validates **every** identifier the statement will carry, not only the obvious one: the
filter columns reach the SQL too.

### An override must delegate, not reimplement

`BuildingDataPostgreSQLConverter.GetUniqueValuesAsync` added a county filter by writing its own
statement, and in doing so dropped the whitelist:

```csharp
// WRONG - what this replaced
string commandQuery = $@"
    SELECT DISTINCT {columnUniqueId}
    FROM {TableName}
    WHERE (@countyId IS NULL OR county_id = @countyId)
      AND {columnUniqueId} IS NOT NULL
    ORDER BY {columnUniqueId}";
```

`columnUniqueId` arrives from the `columnuniqueid` query parameter of
`gis/buildingdata/uniquevalues`, which is public and takes no authentication — so caller-supplied
text was being parsed as SQL, `ORDER BY` included. The fix folded the county into a `FilterGroup` and
called the base method, deleting the raw statement: about 45 lines removed for 18 added, and one code
path instead of two. **A subclass that needs an extra condition expresses it as a filter and
delegates.**

### Finding it from outside

An unknown identifier that answers **500 instead of 404 reached the database**. That is the whole
test, and it needs no payload:

| request | result |
|---|---|
| `uniquevalues?columnuniqueid=no_such_column` | 404 — rejected before any SQL was built |
| `uniquevalues?columnuniqueid=no_such_column&countyid=…` | 500 — the identifier reached PostgreSQL |

A regression test belongs with the fix. `GetUniqueValuesAsync_UnknownColumn_Integration` in
`DiGi.GIS.PostgreSQL.xUnit` asserts that an unknown column is rejected identically on every branch,
and it fails against the unfixed code.

---

## 6. Database Connection Assets & Security

- **Connection Configurations:** Connection strings and server credentials must be loaded from `*.conf` files located in the git-ignored `user files/` directory (e.g. `user files/GIS_PostgreSQL_Main.conf`).
- **Never hardcode credentials:** Never commit connection strings containing passwords, host IPs, or secret tokens to source control.

### A `.conf` never points at production

A `*.conf` resolves to a **development** database: partial, not current, and specific to whichever
machine it sits on. It is the right place to exercise a code path, prove a statement parses, or
create and drop a scratch table. It is **not** the estate.

Production is reached only through the API at `api.digiproject.uk`, and it runs on its own machine —
which also hosts `DiGi.GIS.PostgreSQL.UI`, so a background task's Serilog file is there, not on the
machine the code was edited on.

> **Never answer a question about production by measuring through a `.conf`.** Row counts, coverage,
> "how many rows look like X" — those are production questions and they go through the API. When a
> number measured locally and a number from the API disagree, suspect the databases before the code.

Two conclusions were retracted for want of this rule. A diagnostic run through a conf reported every
one of a county's 155 287 buildings as having a NULL `subdivision_id`, while the deployed
`gis/buildingdata/coveragebycountyid` reported **zero** for the same county — both correct about
their own database, and briefly read as a converter defect. The same mistake later produced "the task
run never happened", from searching an editing machine's log folders for a run that had happened on
the server.

A diagnostic test that reads a database must say **in its own summary** which database its figures
describe. `BuildingDataUnreachableBuildings` in `DiGi.GIS.PostgreSQL.xUnit` is the worked example.

---

## 7. Verification & Detection Checklist

- [ ] Composite unique indexes on nullable columns use `NULLS NOT DISTINCT`?
- [ ] Large collection queries batched in chunks (`batchSize = 1000`) using `ANY(@parameter)`?
- [ ] No per-item `SELECT`/`INSERT` queries executing in a loop?
- [ ] `int commandTimeout = 30` parameter provided and assigned to `npgsqlCommand.CommandTimeout`?
- [ ] `CancellationToken` is the final parameter and passed to all async Npgsql calls?
- [ ] `await using` used for commands, readers, and transactions?
- [ ] Queries use parameterization rather than string concatenation?
- [ ] Dynamic identifiers resolved against the stored column list and quoted, never interpolated raw?
- [ ] Any figure quoted about production measured through the API rather than through a `*.conf`?
