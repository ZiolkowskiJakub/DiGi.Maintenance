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
2. **Parameterized Queries:** Always parameterize input values using `NpgsqlParameter` or `Parameters.AddWithValue`. Never concatenate user input or identifiers into raw SQL strings to prevent SQL injection and enable PostgreSQL query plan caching.
3. **`CancellationToken` Threading:** Always pass `cancellationToken` to all asynchronous Npgsql operations (`ExecuteNonQueryAsync`, `ExecuteReaderAsync`, `ExecuteScalarAsync`, `ReadAsync`).

---

## 5. Database Connection Assets & Security

- **Connection Configurations:** Connection strings and server credentials must be loaded from `*.conf` files located in the git-ignored `user files/` directory (e.g. `user files/GIS_PostgreSQL_Main.conf`).
- **Never hardcode credentials:** Never commit connection strings containing passwords, host IPs, or secret tokens to source control.

---

## 6. Verification & Detection Checklist

- [ ] Composite unique indexes on nullable columns use `NULLS NOT DISTINCT`?
- [ ] Large collection queries batched in chunks (`batchSize = 1000`) using `ANY(@parameter)`?
- [ ] No per-item `SELECT`/`INSERT` queries executing in a loop?
- [ ] `int commandTimeout = 30` parameter provided and assigned to `npgsqlCommand.CommandTimeout`?
- [ ] `CancellationToken` is the final parameter and passed to all async Npgsql calls?
- [ ] `await using` used for commands, readers, and transactions?
- [ ] Queries use parameterization rather than string concatenation?
