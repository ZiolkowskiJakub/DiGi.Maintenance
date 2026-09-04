---
name: coding-postgresql-distributed-queue-processing
description: Use when designing or maintaining distributed bulk update queues in PostgreSQL - table schema (claimed_at, created_at, natural uniqueness), running the queue DDL from every path that touches the table (TableExistsAsync is column-blind), atomic lease claims with FOR UPDATE SKIP LOCKED ordered to match the composite claim index, native interval arithmetic (@minutes * interval '1 minute'), explicit batch acknowledgment (DELETE ... WHERE id = ANY(@ids)), poison-row retirement with an attempt counter and retirement ceiling, crash recovery, and non-destructive queue observation.
---

# AI Guidelines: PostgreSQL Distributed Queue Processing

**Environment:** PostgreSQL 15+ / 18, Npgsql, ASP.NET Core, .NET 9.0+, C# 10+.  
**Domain:** Distributed background processing, multi-machine bulk updates, resilient claim/acknowledge queues, and GIS data pipelines (`DiGi.PostgreSQL`, `DiGi.GIS.PostgreSQL`, `DiGi.GIS.WebAPI`).

---

## 1. Architectural Overview & Workflow

When processing millions of records across multiple machines (e.g., downloading orthophotos/satellite imagery for building footprints, running ML inference, or performing heavy geometric transformations), updating records directly in monolithic loops or fetching items with immediate deletion causes catastrophic failure modes.

### 🚫 The Destructive Drain Anti-Pattern
A naive implementation reads and removes work in a single step (`DELETE FROM queue ... RETURNING ...`).
- **Work is lost on failure:** If a worker crashes, times out, loses network connectivity, or fails during downstream processing, the deleted rows are gone permanently.
- **The queue is unobservable:** A queue that deletes on read cannot be inspected. Administrators and monitoring tools cannot measure queue depth, track age, or detect stalled partitions without draining the queue.

### The 4-Stage Claim/Acknowledge Pipeline
The DiGi distributed queue architecture separates data staging from destructive consumption using a robust four-stage lifecycle:

```mermaid
sequenceDiagram
    autonumber
    participant Producer as Producer / Refresh Task
    participant DB as PostgreSQL Queue Table
    participant Monitor as Queue Summaries (Read-Only)
    participant Worker as Worker Nodes (Multi-Machine)
    participant Target as Target Storage (Data Table)

    Producer->>DB: 1. Enqueue Delta (ON CONFLICT DO NOTHING)
    Monitor->>DB: 2. Observe Queue Depth & Age (Read-Only)
    Worker->>DB: 3. Atomic Lease Claim (UPDATE ... FOR UPDATE SKIP LOCKED)
    Note over Worker: Download / Process / Transform Data
    Worker->>Target: 4a. Persist Results (UpdateAsync)
    alt Persist Succeeded
        Worker->>DB: 4b. Acknowledge Batch (DELETE WHERE id = ANY(@ids))
    else Persist Failed or Worker Crashed
        Note over DB: Lease expires (now() > claimed_at + timeout).<br/>Item automatically returns to queue.
    end
```

1. **Enqueue / Refresh:** The producer identifies missing or outdated records across partitions, preparing delta records and inserting them into the queue with `ON CONFLICT DO NOTHING` for idempotency.
2. **Observe:** Read-only summary endpoints report queue depth, age distribution, and partition statistics without claiming or modifying rows.
3. **Atomic Claim:** Workers lease batches non-destructively by setting `claimed_at = now()` using `FOR UPDATE SKIP LOCKED`.
4. **Two-Phase Acknowledge:** After successfully storing the computed results into the target table, the worker explicitly deletes the completed queue IDs. If a failure occurs, acknowledgment is skipped, and the expired lease returns the item to the queue automatically.

---

## 2. Queue Table Schema & Index Standards

Update queue tables are stored as single unpartitioned tables named `{TargetTable}_{EntityType}_update` (e.g., `orto_datas_building_2d_reference_update`).

### Standard DDL Definition
The DDL method in `Create/TableAsync.cs` must define the table with both creation and migration statements:

```sql
CREATE TABLE IF NOT EXISTS {tableName} (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    county_id INT NOT NULL,
    reference TEXT NOT NULL,
    subdivision_id INT,
    created_at timestamptz DEFAULT now(),
    claimed_at timestamptz,
    PRIMARY KEY (id, county_id)
);

-- Backward-compatible column migration for existing databases
ALTER TABLE {tableName} ADD COLUMN IF NOT EXISTS claimed_at timestamptz;

-- Prevent duplicate queuing of the same entity within a partition
CREATE UNIQUE INDEX IF NOT EXISTS idx_{tableName}_county_id_reference
    ON {tableName} (county_id, reference);

-- FIFO ordering index for queue processing
CREATE INDEX IF NOT EXISTS idx_{tableName}_created_at
    ON {tableName} (created_at ASC);

-- Optimized index for claiming unclaimed or expired items
CREATE INDEX IF NOT EXISTS idx_{tableName}_claimed_at
    ON {tableName} (claimed_at ASC NULLS FIRST, created_at ASC);
```

### Key Schema Rules
1. **`id BIGINT GENERATED ALWAYS AS IDENTITY`:** Serves as the unique identity handle passed back to workers and used for explicit batch deletion.
2. **`claimed_at timestamptz` (Nullable):** `NULL` indicates the item is ready to be processed. A timestamp indicates an active lease.
3. **`UNIQUE (county_id, reference)`:** Enforces that a refresh run appending tens of thousands of references never enqueues duplicates.
4. **Composite Claim Index:** `(claimed_at ASC NULLS FIRST, created_at ASC)` allows PostgreSQL to quickly scan for unclaimed items (`NULLS FIRST`) or expired leases in FIFO creation order.

### DDL Ownership — Every Path Runs It
The DDL method in `Create/TableAsync.cs` is the migration, and a consumer may be the first path to reach a table that predates a schema change. **Every path that reads or writes the queue table — enqueue, claim, acknowledge — runs the DDL before its own statement**, not just the producer.

`TableExistsAsync` is `SELECT to_regclass(...)`: it answers for the table and knows nothing about its columns. On a table created before `claimed_at` existed, the guard passes and the claim then raises `42703` on the column the migration was supposed to add — the failure behind `ZiolkowskiJakub/DiGi.GIS.PostgreSQL#46`, which made the deployed download task report Failed. Because every DDL statement is conditional (`CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`), running it from every path costs a catalog lookup and is exactly what the enqueue path already does.

---

## 3. Atomic Lease Claiming (`FOR UPDATE SKIP LOCKED`)

### The Claim SQL Statement
Claiming rows must be atomic, non-blocking for concurrent workers, and non-destructive:

```sql
UPDATE {TableName.OrtoDatas_Building2DReference_Update}
SET claimed_at = now()
WHERE id IN (
    SELECT id FROM {TableName.OrtoDatas_Building2DReference_Update}
    WHERE claimed_at IS NULL OR claimed_at < now() - (@claimTimeoutMinutes * interval '1 minute')
    ORDER BY claimed_at ASC NULLS FIRST, created_at ASC
    FOR UPDATE SKIP LOCKED
    LIMIT @count
)
RETURNING id, county_id, reference, subdivision_id;
```

### Critical Mechanics & Gotchas
- **`FOR UPDATE SKIP LOCKED`:** Tells PostgreSQL to skip any rows currently locked by other concurrent worker transactions rather than waiting. This allows dozens of worker machines to pull batches simultaneously without lock contention or duplicate work.
- **`ORDER BY claimed_at ASC NULLS FIRST, created_at ASC` — the index it scans.** This matches the composite claim index created in section 2, so the claim scans that index instead of sorting a heap. The order is also a fairness rule: never-claimed rows sort first, so a row whose lease expired waits behind everything never attempted. Ordered by `created_at` alone, an expired lease returns to the **head** of the queue, and a worker failing on the rows it reaches first can re-attempt them forever ahead of the rest.
- **The claim path runs the DDL first (section 2), not a `TableExistsAsync` guard.** The claim statement reads and writes `claimed_at`; on a table predating the column the existence guard passes and the statement raises `42703`.
- **Lease Timeout via Native Arithmetic:** Use `(@claimTimeoutMinutes * interval '1 minute')` rather than string concatenation (`(@claimTimeoutMinutes || ' minutes')::interval`). In PostgreSQL, integer multiplication with an `interval` is native and prevents syntax or type-casting errors.
- **Re-Queueing on Crash:** If a worker machine dies or drops network connection, the lease expires when `now() - claimed_at > claimTimeoutMinutes`. The next claiming worker will automatically pick up the abandoned rows.

### Converter Method Signature Standard
```csharp
public static async Task<List<Building2DReference>?> GetNextBuilding2DReferencesAsync(
    NpgsqlConnection? npgsqlConnection,
    int count = 100,
    int claimTimeoutMinutes = 30,
    int commandTimeout = 60,
    CancellationToken cancellationToken = default)
```
- Expose both `static` (accepting `NpgsqlConnection?`) and instance extension methods.
- Always thread `cancellationToken` and apply `commandTimeout` to `NpgsqlCommand`.

---

## 4. Two-Phase Processing & Batch Acknowledgment

Workers must explicitly acknowledge successfully processed items by deleting their queue IDs.

### Acknowledgment SQL Statement
```sql
DELETE FROM {TableName.OrtoDatas_Building2DReference_Update}
WHERE id = ANY(@ids);
```

### Converter Implementation Pattern
```csharp
public static async Task<long> AcknowledgeBuilding2DReferencesAsync(
    NpgsqlConnection? npgsqlConnection,
    IEnumerable<long>? ids,
    int commandTimeout = 60,
    CancellationToken cancellationToken = default)
{
    if (npgsqlConnection is null || ids is null)
    {
        return -1;
    }

    long[] ids_Array = [.. ids];
    if (ids_Array.Length == 0)
    {
        return 0;
    }

    // The DDL rather than a mere existence check, for the same reason the claim runs it: a queue
    // table predating the claim column has to be brought up to the current shape by whichever path
    // reaches it first. Every statement in it is conditional, so this is a catalog lookup.
    if (!await Create.TableAsync_Building2DReference(npgsqlConnection, TableName.OrtoDatas_Building2DReference_Update, commandTimeout, cancellationToken))
    {
        return -1;
    }

    string commandText = $@"
        DELETE FROM {TableName.OrtoDatas_Building2DReference_Update}
        WHERE id = ANY(@ids);";

    try
    {
        await using NpgsqlCommand command = new(commandText, npgsqlConnection);
        command.CommandTimeout = commandTimeout;
        command.Parameters.Add(new NpgsqlParameter("ids", NpgsqlDbType.Array | NpgsqlDbType.Bigint) { Value = ids_Array });

        return await command.ExecuteNonQueryAsync(cancellationToken);
    }
    catch (NpgsqlException npgsqlException)
    {
        Serilog.Modify.Log(npgsqlException, "{Method} failed while acknowledging {Count} references", nameof(AcknowledgeBuilding2DReferencesAsync), ids_Array.Length);
        return -1;
    }
}
```

`-1` and `0` are different answers: `0` is a count of rows retired and must never stand for a failure, so the path returns `-1` whenever the table cannot be prepared. The WebAPI layer maps any negative result to `500` (section 6).

### The Golden Rule of Acknowledgment
> **NEVER acknowledge items before their target data is committed.**
> Acknowledgment belongs strictly *after* `UpdateAsync` / storage commit succeeds. If saving fails or throws, skip acknowledgment so the lease expires and the work is safely retried.

### Poison Rows — Attempt Counter & Retirement Ceiling

With acknowledgment correctly confined to work that was stored, a reference that can **never** resolve is never retired: the lease expires, the row is claimed again, it fails again, and the queue acquires a floor of permanently failing rows that a worker keeps reaching. A queue without an attempt counter cannot tell a transient fault from a data defect.

The standard guard has three parts:

1. **Attempt counter.** New queue tables carry an attempt count, added by migration for existing ones:
   ```sql
   ALTER TABLE {tableName} ADD COLUMN IF NOT EXISTS attempts INT NOT NULL DEFAULT 1;
   ```
   The claim increments it, so every re-attempt after an expired lease is counted:
   ```sql
   UPDATE {tableName}
   SET claimed_at = now(), attempts = COALESCE(attempts, 0) + 1
   WHERE id IN (
       SELECT id FROM {tableName}
       WHERE claimed_at IS NULL OR claimed_at < now() - (@claimTimeoutMinutes * interval '1 minute')
         AND COALESCE(attempts, 0) < @maxAttempts
       ORDER BY claimed_at ASC NULLS FIRST, created_at ASC
       FOR UPDATE SKIP LOCKED
       LIMIT @count
   )
   RETURNING id, county_id, reference, subdivision_id;
   ```
   `COALESCE` keeps rows predating the column claimable. `@maxAttempts` is a method parameter beside `claimTimeoutMinutes`; the ceiling is a policy decision — high enough that transient faults (network, service outage) recover before it is reached, low enough that a reference that can never resolve is retired rather than cycled forever.
2. **Retirement ceiling.** The claim method retires exhausted rows **before** it claims, so no worker ever sees them again:
   ```sql
   DELETE FROM {tableName}
   WHERE COALESCE(attempts, 0) >= @maxAttempts
   RETURNING id, county_id, reference;
   ```
   Every retired reference is logged at error level with enough identity (partition + reference) to file a data defect — a permanently failing reference is a problem worth a ticket, never a silent drop.
3. **Retirement is not acknowledgment.** Acknowledgment retires rows whose work was **stored**; retirement discards rows whose work **provably failed** its ceiling of attempts. Both are explicit deletions, but they answer different questions, and only the former belongs inside the worker loop.

> **Current state:** the `orto_datas_building_2d_reference_update` queue predates this standard and carries no attempt counter yet — adoption is tracked in `ZiolkowskiJakub/DiGi.GIS.PostgreSQL#48`. The samples in sections 2–4 reflect the queue as it exists today; this subsection is the target for new queues.

---

## 5. Non-Destructive Queue Observation

Distributed queues must be observable without modifying state or disturbing worker nodes.

The observation path is the one deliberate exception to the DDL ownership rule in section 2: it keeps `TableExistsAsync` on purpose, because an observation endpoint must not create anything. `null` there correctly means no refresh has ever run — a fact, not a fault.

### Query Implementation Pattern
```csharp
public static async Task<List<OrtoDatasQueueResult>?> GetQueueSummariesByCountyIdsAsync(
    NpgsqlConnection? npgsqlConnection,
    IEnumerable<int>? countyIds,
    int commandTimeout = 600,
    CancellationToken cancellationToken = default)
{
    if (npgsqlConnection is null)
    {
        return null;
    }

    if (!await DiGi.PostgreSQL.Query.TableExistsAsync(npgsqlConnection, TableName.OrtoDatas_Building2DReference_Update))
    {
        return null;
    }

    int[]? countyIds_Array = countyIds is null ? null : [.. countyIds];

    string commandText = $@"
        SELECT
            county_id,
            COUNT(*),
            COUNT(*) FILTER (WHERE subdivision_id IS NOT NULL),
            MIN(created_at), MAX(created_at)
        FROM {TableName.OrtoDatas_Building2DReference_Update}
        {(countyIds_Array is null ? string.Empty : "WHERE county_id = ANY(@countyIds)")}
        GROUP BY county_id
        ORDER BY county_id;";

    await using NpgsqlCommand npgsqlCommand = new(commandText, npgsqlConnection);
    npgsqlCommand.CommandTimeout = commandTimeout;
    if (countyIds_Array is not null)
    {
        npgsqlCommand.Parameters.Add(new NpgsqlParameter("countyIds", NpgsqlDbType.Array | NpgsqlDbType.Integer) { Value = countyIds_Array });
    }

    List<OrtoDatasQueueResult> result = [];
    await using NpgsqlDataReader npgsqlDataReader = await npgsqlCommand.ExecuteReaderAsync(cancellationToken);
    while (await npgsqlDataReader.ReadAsync(cancellationToken))
    {
        result.Add(new OrtoDatasQueueResult(
            npgsqlDataReader.GetInt32(0),
            npgsqlDataReader.GetInt64(1),
            npgsqlDataReader.GetInt64(2),
            npgsqlDataReader.IsDBNull(3) ? null : npgsqlDataReader.GetFieldValue<DateTimeOffset>(3),
            npgsqlDataReader.IsDBNull(4) ? null : npgsqlDataReader.GetFieldValue<DateTimeOffset>(4)));
    }

    return result;
}
```

### Summary Requirements
- Group by partition/scope (e.g. `county_id`).
- Report total count (`COUNT(*)`), filtered counts (e.g. `COUNT(*) FILTER (...)`), and oldest/newest timestamps (`MIN(created_at)`, `MAX(created_at)`).
- An empty result or `404 NotFound` indicates the queue is drained or not initialized.

---

## 6. WebAPI Controller & Client Endpoints

### Controller Endpoints
Controllers expose two endpoints for queue interaction:

```csharp
[HttpPost("nextbuilding2dreferences", Name = $"{nameof(OrtoDatasController)}_{nameof(NextBuilding2DReferencesAsync)}")]
[ProducesResponseType(typeof(List<Building2DReference>), StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status204NoContent)]
[ProducesResponseType(StatusCodes.Status400BadRequest)]
public async Task<IActionResult> NextBuilding2DReferencesAsync(
    [FromQuery(Name = "count")] int count = 100,
    [FromQuery(Name = "claimtimeoutminutes")] int claimTimeoutMinutes = 30,
    [FromQuery(Name = "commandtimeout")] int commandTimeout = 60,
    CancellationToken cancellationToken = default)
{
    if (count <= 0) return BadRequest("Count must be greater than 0.");
    if (claimTimeoutMinutes <= 0) return BadRequest("Claim timeout minutes must be greater than 0.");
    if (ortoDatasPostgreSQLConverter is null) return BadRequest();

    List<Building2DReference>? references = await ortoDatasPostgreSQLConverter.GetNextBuilding2DReferencesAsync(
        count, claimTimeoutMinutes, commandTimeout, cancellationToken: cancellationToken);

    if (references is null || references.Count == 0) return NoContent();

    return Content(Core.Convert.ToSystem_String(references) ?? string.Empty, "application/json");
}

[HttpPost("acknowledgebuilding2dreferences", Name = $"{nameof(OrtoDatasController)}_{nameof(AcknowledgeBuilding2DReferencesAsync)}")]
[ProducesResponseType(typeof(long), StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status400BadRequest)]
[ProducesResponseType(StatusCodes.Status500InternalServerError)]
public async Task<IActionResult> AcknowledgeBuilding2DReferencesAsync(
    [FromBody] IEnumerable<long>? ids,
    CancellationToken cancellationToken = default)
{
    if (ids is null || !ids.Any()) return BadRequest("The ids collection cannot be null or empty.");
    if (ortoDatasPostgreSQLConverter is null) return BadRequest();

    long count_Deleted = await ortoDatasPostgreSQLConverter.AcknowledgeBuilding2DReferencesAsync(ids, cancellationToken: cancellationToken);
    if (count_Deleted < 0) return StatusCode(500, "Internal server error during acknowledgement");

    return Ok(count_Deleted);
}
```

### Worker / Background Task Loop
```csharp
while (postResponse_References?.Result is List<Building2DReference> references && references.Count > 0)
{
    cancellationToken.ThrowIfCancellationRequested();

    // 1. Process batch
    List<OrtoDatas> processedData = await ProcessBatchAsync(references, cancellationToken);

    // 2. Persist to storage
    bool saved = await TargetConverter.UpdateAsync(processedData);

    // 3. Acknowledge only on success
    if (saved)
    {
        List<long> ids = [.. references.Where(x => x.Id > 0).Select(x => x.Id)];
        if (ids.Count > 0)
        {
            await AcknowledgeAsync(ids, cancellationToken);
        }
    }

    // 4. Fetch next batch
    postResponse_References = await FetchNextBatchAsync(cancellationToken);
}
```

---

## 7. Implementation Checklist

When implementing a new distributed queue in DiGi solutions, verify:

- [ ] Queue table schema includes `claimed_at timestamptz` and migration statement?
- [ ] Every claim and acknowledge path runs the DDL rather than checking existence?
- [ ] Unique constraint on `(partition_id, reference)` prevents duplicate queuing?
- [ ] Composite index on `(claimed_at ASC NULLS FIRST, created_at ASC)` created?
- [ ] Claim statement orders by `claimed_at ASC NULLS FIRST, created_at ASC`, so an expired lease cannot pre-empt never-attempted rows?
- [ ] Claim statement uses `FOR UPDATE SKIP LOCKED` and native interval multiplication (`@minutes * interval '1 minute'`)?
- [ ] Claim method accepts `count`, `claimTimeoutMinutes`, `commandTimeout`, and `CancellationToken`?
- [ ] Acknowledge method deletes by ID array (`WHERE id = ANY(@ids)`)?
- [ ] Attempt counter with a retirement ceiling retires permanently failing references, logged at error?
- [ ] Workers invoke acknowledgment **only after** storage write completes successfully?
- [ ] Read-only observation endpoint (`queuesummaries...`) exists and does not drain the queue?
- [ ] All public methods and endpoints have comprehensive XML documentation?
