
Postgresql Architecture (Practical)

Application
    ↓
Connection
    ↓
PostgreSQL
    ├── Parser
    ├── Planner/Optimizer
    ├── Executor
    │
    ├── Shared Buffers
    ├── WAL
    ├── Checkpoints
    ├── MVCC
    ├── Autovacuum
    │
    └── Storage
understand WAL + connection pooling.

Understand → not master.

You should be able to explain:

Connections — how applications connect to PostgreSQL
Connection pooling — why applications shouldn't create unlimited connections
Transactions — how PostgreSQL maintains consistency
MVCC — how concurrent transactions work at a practical level
WAL — how PostgreSQL provides durability and enables recovery/replication
Checkpoints — why PostgreSQL periodically flushes changes
Vacuum/autovacuum — why PostgreSQL needs maintenance
Locks — why transactions can block each other
Planner/executor — enough to understand EXPLAIN
Storage — basic awareness of where the data ultimately lives

Linux/Ubuntu Learning Practical

Filesystem
├── /etc
├── /var
├── /var/log
├── /tmp
└── permissions

Processes
├── ps
├── top
├── kill
└── systemctl

Users & permissions
├── user
├── group
├── chmod
├── chown
└── sudo

Networking
├── ip
├── ss
├── ping
├── curl
└── DNS basics

Storage
├── df
├── du
├── mount
└── basic disk concepts

Services
├── systemctl
├── journalctl
└── service logs

Shell
├── bash
├── pipes
├── redirects
├── grep
├── find
├── less
└── basic scripting

Then move directly into administration

Something like:

PostgreSQL architecture
       ↓
Basic administration
       ↓
Security / roles
       ↓
Backup & restore
       ↓
WAL / recovery
       ↓
Monitoring
       ↓
Performance
       ↓
Replication
       ↓
Cloud PostgreSQL


Good instinct — reading about this only sticks once you've seen a plan. But the parser/executor concepts are worth nailing down first, because they explain why indexes and EXPLAIN even exist.

The big picture: what happens when you run a query
text

Copy
Your SQL text
     ↓
[1] Parser  ──→ "Is this valid syntax? What does it mean?"
     ↓
[2] Rewriter/Planner/Optimizer ──→ "What's the cheapest way to get these rows?"
     ↓
[3] Executor ──→ "Actually go fetch the data."
     ↓
Rows returned
Let's take them one at a time.

1. The Parser
The parser takes your raw SQL text and turns it into a structured tree (an AST — Abstract Syntax Tree). It answers only:

Is the syntax correct? (SELECT ... FROM ... WHERE ...)
Are keywords in the right order?
Do parentheses match?
Which parts are columns, tables, operators, literals?
Example:

sql

Copy
SELECT name FROM users WHERE age > 30;
becomes roughly:

text

Copy
SelectStmt
├── targetList: ColumnRef(name)
├── fromClause: RangeVar(users)
└── whereClause: A_Expr(> , ColumnRef(age), A_Const(30))
Key point: the parser does not check whether the table exists or pick any strategy. It only checks grammar. That's why you can have perfectly parseable SQL that fails later ("relation does not exist").

In SQL Server, this is done by the query compiler/binder phase; same idea — validate structure and resolve names before optimizing.

2. The Executor
The executor is the part that actually does the work. After the optimizer has chosen a plan (a tree of operations like Seq Scan → Hash Join → Sort), the executor walks that tree row-by-row and produces results.

Two execution models matter conceptually:

Iterator / volcano model (Postgres): each node pulls a batch of rows from its child, processes them, passes them up. This is why you see plans as nested trees.
Batch-at-a-time (SQL Server): similar but optimized for set-based operations with vectorized-ish processing.
For our example, if there's no index, the executor will:

Read every page of users from disk/memory (Seq Scan)
Check age > 30 on each row (Filter)
Emit matching rows upward
If there is an index on age, the plan changes and the executor instead does an Index Scan, touching far fewer pages.

Why this matters for indexing
This is the whole reason your earlier question about indexes matters:

Stage	What it decides	How indexes affect it
Parser	Nothing about performance	None
Planner/Optimizer	Which plan to use (scan vs. index scan, join order)	Indexes give it cheaper options to choose from
Executor	Runs whatever was chosen	An index scan touches fewer pages = faster
So:

EXPLAIN shows you the planner's chosen plan (before/during execution).
EXPLAIN ANALYZE additionally runs the executor and reports actual time + rows per node.
When you saw Seq Scan vs Index Scan in those plans, you were literally watching the planner's choice being carried out by the executor.

One-line summary
Parser = grammar checker (SQL text → tree). Executor = the engine that runs the chosen plan and returns rows. The planner sits between them and is the piece that decides whether your indexes help.

Want me to walk through a real EXPLAIN (ANALYZE) output line by line so you can see which parts come from the planner vs. the executor?

Copied





Qwen 3.5 122B

I'll be glad 
Let's walk through a real EXPLAIN (ANALYZE) output. I'll use a simple query and decode every visible part.

The Setup
text

Copy
Table: orders
- id: integer (PK)
- customer_id: integer
- total: numeric
- created_at: timestamp
Query:

sql

Copy
EXPLAIN (ANALYZE, BUFFERS)
SELECT total FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 10;
The Output (typical PostgreSQL)
text

Copy
Limit  (cost=8.30..8.32 rows=10 width=8) (actual rows=10 loops=1)
  Output: total
  Buffers: shared hit=5
  ->  Index Scan using idx_orders_customer_created on public.orders
        (cost=8.30..12.50 rows=1 width=8) (actual rows=10 loops=1)
        Output: total
        Index Cond: (customer_id = 42)
        Buffers: shared hit=5
Planning Time: 0.150 ms
Execution Time: 0.230 ms
Line-by-line breakdown
Line 1: Limit
text

Copy
Limit  (cost=8.30..8.32 rows=10 width=8) (actual rows=10 loops=1)
Field	Meaning
Limit	This node's job is to stop after the first 10 rows
cost=8.30..8.32	Estimated cost to start returning rows (8.30) vs. cost to finish (8.32). Small range = planner is confident
rows=10	Planner's estimate of how many rows this node will emit
width=8	Estimated width of each row in bytes (here, just a numeric column)
actual rows=10	Executor actually returned 10 rows
loops=1	This node ran once (for Limit, always 1)
Key takeaway: The top node is always the final operation. Cost flows upward — the bottom of the tree does the heavy lifting, and cost accumulates.

Line 2: Output: total
Just declaring what columns this node produces. Not a decision — just metadata.

Line 3: Buffers: shared hit=5
The executor touched 5 pages entirely in memory (no disk read). This is your I/O cost proxy — fewer = faster.

Line 4: Index Scan using idx_orders_customer_created
This is the worker — the actual data fetch strategy.

text

Copy
Index Scan using idx_orders_customer_created on public.orders
  (cost=8.30..12.50 rows=1 width=8) (actual rows=10 loops=1)
  Output: total
  Index Cond: (customer_id = 42)
  Buffers: shared hit=5
Field	Meaning
Index Scan	Planner chose to use the index directly (not a Seq Scan). This is the "aha" moment — your index is being used.
using idx_orders_customer_created	Which index
cost=8.30..12.50	Estimated cost to first row (8.30) through all matching rows (12.50)
rows=1	Planner estimated only ~1 row matched customer_id = 42
actual rows=10	Executor found 10 rows. The estimate was off — but not catastrophically so
Index Cond: (customer_id = 42)	The filter condition that drove the index lookup. This is the planner's way of saying "we're scanning the index with this predicate."
Lines 5–6: Planning Time / Execution Time
Planning Time: 0.150 ms — time the planner took to choose this plan
Execution Time: 0.230 ms — time the executor took to run it
For this query, planning time is negligible. For complex queries with joins, subqueries, or many indexes, planning time can run into seconds or minutes.

What you should see if the index was missing
text

Copy
Limit  (cost=152.30..152.32 rows=10 width=8) (actual rows=10 loops=1)
  ->  Sort  (cost=152.30..155.30 rows=1200 width=8)
        Sort Key: created_at DESC
        ->  Seq Scan on orders
              Filter: (customer_id = 42)
              Rows Removed by Filter: 998800
Compare:

Seq Scan instead of Index Scan → reads the whole table
Sort node → had to sort all matching rows because the index isn't ordered by created_at
Rows Removed by Filter: 998800 → scanned ~1M rows, threw away ~999K
Higher cost everywhere
How to read this yourself — a mental checklist
When you see any EXPLAIN (ANALYZE) output, ask:

What's the top node? That's the final operation (Limit, Sort, Seq Scan, etc.)
Seq Scan or Index Scan? Seq Scan = full table. Index Scan = index is helping.
Are there Sort nodes? If yes and the data is already ordered, that's wasted work.
Compare rows vs actual rows: Big discrepancy → statistics may be stale, or the planner made a bad guess.
Look at Buffers: High "read" (low "hit") means disk I/O — that's your enemy.
What's the Index Cond? This tells you which index condition was actually used.
Common patterns to recognize
text

Copy
Seq Scan + Filter  →  Consider an index on the filtered column
Sort + Seq Scan    →  Consider an index matching the ORDER BY
Hash Join / Nested Loop → Join strategy; cost tells you which the planner chose
Bitmap Index Scan   →  Index used, but for a range or multiple values (not as precise as Index Scan)
Want to paste your own EXPLAIN (ANALYZE) output and I'll walk through it the same way? Or if you're on SQL Server, we can do the equivalent with the XML plan or STATISTICS PROFILE output.

Copied





Qwen 3.5 35B

what about shared bufferes  wal checkpoints mvcc and  autovacuum are there  working together
Yes — these four are deeply intertwined. They're not independent subsystems; they form a feedback loop where each one's behavior directly affects the others. Understanding this is what separates someone who can tune Postgres from someone who just runs VACUUM when things get slow.

Let me walk through how they connect, then show you the cycle.

What each one does (quick recap)
Component	Core job
Shared Buffers	RAM cache of disk pages. All reads/writes go through here first.
WAL (Write-Ahead Log)	Crash-proof journal. Every change is logged before the data page is modified.
Checkpoints	Periodically flush dirty buffers to disk so WAL doesn't grow forever.
MVCC	Multi-Version Concurrency Control. Updates don't overwrite rows — they create new row versions. Old versions stay until no transaction needs them.
Autovacuum	Background cleanup that removes dead row versions and updates statistics.
The causal chain — how they feed each other
1. MVCC creates garbage → Autovacuum cleans it → which creates more work for everything else
When you do:

sql

Copy
UPDATE orders SET total = 99 WHERE id = 42;
MVCC doesn't modify the row in place. It:

Writes a new tuple version with the updated value
Marks the old tuple as "dead" (but keeps it visible to older transactions)
Logs both operations in the WAL
Now the old version sits in a shared buffer page. That page is now dirty. Autovacuum will eventually come along, mark the old tuple as truly removable, and free space inside the page. But freeing space inside a page still means the page was modified → more WAL, more dirty buffers, more checkpoint pressure.

This is the key insight: autovacuum itself generates I/O and WAL traffic. A busy table with lots of UPDATE/DELETE has autovacuum constantly working, which feeds back into checkpoints and shared buffers.

2. Checkpoints force dirty pages to disk → but WAL lets writes be cheap
Without WAL, every UPDATE would need to write the actual data page to disk before committing — brutally slow. Instead:

text

Copy
Transaction commits → only WAL record is fsync'd (fast, sequential)
                      Data page stays dirty in shared buffers

Checkpoint happens   → all dirty pages get written to disk in bulk
                      (expensive, random I/O spike)
So checkpoints defer the expensive random I/O. But if you have lots of MVCC churn creating lots of dirty pages, checkpoints become heavier and more frequent.

3. Shared buffers size determines how much dirty data accumulates between checkpoints
Small shared_buffers → pages get evicted quickly → more frequent checkpoint flushing → more I/O spikes
Large shared_buffers → more dirty pages can accumulate → fewer but larger checkpoints → bigger I/O spikes when they hit
The sweet spot is usually ~25% of RAM, but it interacts with your workload's update rate.

4. WAL volume drives checkpoint frequency
Checkpoints happen based on either:

Time interval (checkpoint_timeout, default 5 min), OR
Amount of WAL generated since last checkpoint (max_wal_size)
If your workload generates heavy WAL (lots of MVCC updates + autovacuum rewrites), you'll hit max_wal_size before the timeout. Result: checkpoints fire early and aggressively, causing periodic I/O storms.

This is one of the most common production issues: "Postgres gets slow every few minutes" → almost always checkpoint-related.

The full feedback loop
text

Copy
                    ┌──────────────┐
         ┌─────────→│     MVCC     │←──────────┐
         │          └──────┬───────┘           │
         │                 │ creates dead      │
         │                 │ tuples            │ new versions
         │                 ▼                   │ on every write
         │          ┌──────────────┐           │
         │          │  Autovacuum  │           │
         │          └──────┬───────┘           │
         │                 │ rewrites pages    │
         │                 │ (generates        │
         │                 ▼  more WAL)        │
         │          ┌──────────────┐           │
         │          │ Shared       │           │
         │          │ Buffers      │───────────┘
         │          │ (dirty pages)│
         │          └──────┬───────┘
         │                 │ flushed by
         │                 ▼
         │          ┌──────────────┐
         │          │ Checkpoints  │
         │          └──────┬───────┘
         │                 │ triggers
         │                 ▼
         │          ┌──────────────┐
         └──────────│     WAL      │
                    └──────────────┘
Every component feeds the next. Change one setting, and you ripple through all of them.

Practical implications — what this means for tuning
If you have heavy UPDATE/DELETE workloads:
Autovacuum becomes critical — if it falls behind, tables bloat, scans slow down, shared buffers fill with dead tuples, and everything degrades. Watch:

sql

Copy
SELECT relname, n_dead_tup, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 10;
Increase max_wal_size so checkpoints don't fire too often:

ini

Copy
max_wal_size = 4GB          # default 1GB — often too low for write-heavy DBs
checkpoint_completion_target = 0.9  # spread checkpoint I/O over time
Consider HOT updates — if an UPDATE doesn't touch indexed columns, Postgres can do a Heap-Only Tuple update inside the same page without touching indexes or generating as much WAL. This requires enough free space in pages, which is why fillfactor matters:

sql

Copy
ALTER TABLE orders SET (fillfactor = 70);
-- Leaves 30% of each page free for HOT updates
Monitor checkpoint timing — if you see frequent checkpoints, increase max_wal_size:

sql

Copy
SELECT * FROM pg_stat_bgwriter;
-- checkpoints_req = checkpoints triggered by WAL pressure (bad if high)
-- checkpoints_timed = normal timed checkpoints (good)
If you have read-heavy workloads:
Shared buffers matter most — keep hot data cached
Autovacuum still matters but less aggressively
Checkpoints are lighter because there's less WAL
One-sentence summary
MVCC makes writes cheap but creates garbage; autovacuum cleans garbage but generates more writes; those writes dirty shared buffers; checkpoints flush dirty buffers using WAL as the safety net — and each step's load determines the next step's pressure.

Want me to help you check your current settings against your workload type? Just share your postgresql.conf values for shared_buffers, max_wal_size, checkpoint_timeout, and autovacuum settings, plus whether you're read-heavy or write-heavy.

Copied





Qwen 3.5 122B

yes please.. so is this all I need to learn for this matter?
No. You've learned the mechanics (how it works), but to tune it you need to understand the trade-offs and the diagnostics.

Here is the rest of the picture. These are the pieces that turn "knowing what it is" into "knowing how to fix it."

1. The "Dirty" Trade-off: Durability vs. Performance
You asked about WAL and checkpoints. The core conflict is:

Durability: If power cuts, your COMMIT must be safe. WAL guarantees this.
Performance: Writing to WAL is fast (sequential I/O). Writing data pages is slow (random I/O).
The Tuning Knob: synchronous_commit

on (default): Fast writes, but if the OS crashes between WAL write and data flush, you lose transactions.
off: Very fast writes, but high risk of data loss on crash.
remote_write (async): Best of both worlds for performance, but tiny risk.
Why it matters: If you are importing millions of rows, you can temporarily set synchronous_commit = off to speed up inserts 10x. Then set it back to on.

2. The Vacuum Dilemma: Space Reclamation vs. Performance
When Autovacuum deletes dead rows, it doesn't always shrink the file on disk. It often just marks the space as "reusable."

Bloat: If you update rows constantly, the file grows huge (containing lots of dead tuples). Scans become slower because they read more dead data.
Shrink: To actually reduce file size, you need VACUUM FULL or pg_repack. But VACUUM FULL locks the table completely (no reads/writes).
The Tuning Knob: autovacuum_vacuum_cost_delay

Default is 2ms. This slows down Autovacuum to avoid starving your user queries.
If your disk is fast and you have downtime, lower this to 0. Autovacuum runs faster, reducing bloat quicker.
If your disk is slow, raise it to 20ms. Autovacuum runs slower, but doesn't slow down your users.
3. The Planner's Blind Spot: Statistics
The Planner (which we discussed) makes decisions based on Statistics. The Executor runs the plan. If the stats are wrong, the plan is wrong.

Example:

You have an index on status.
Stats say 50% of rows are 'active'.
You query WHERE status = 'active'.
Planner thinks: "50% is too much for an index; I'll do a Seq Scan."
Reality: Only 1% are 'active'. Index would be faster.
Result: Slow query.
The Fix: ANALYZE (or autoanalyze) updates stats.

If you bulk-load data, run ANALYZE immediately.
If you have skewed data (e.g., 99% one value, 1% another), you might need Extended Statistics or Column Statistics (ALTER TABLE ... ALTER COLUMN ... SET STATISTICS 1000).
4. The Memory Hierarchy: Shared vs. Work
You asked about Shared Buffers. But there's another memory zone: Work Memory.

Shared Buffers: Cache for data pages (the table files). Shared by all connections.
Work Mem: Memory for operations like Sorting, Hash Joins, Aggregations. Per-connection.
The Trap:

work_mem is small by default (4MB).
If a sort exceeds work_mem, Postgres writes to disk (temp file). This is slow.
If you increase work_mem to 100MB, and you have 100 connections doing complex sorts, you might use 10GB of RAM and crash the server.
The Rule: Tune work_mem based on your worst query, not your average. And keep an eye on connection count.

5. The Diagnostic Tool: pg_stat_statements
You can't tune what you can't measure. This extension tracks the slowest queries by total execution time.

sql

Copy
SELECT query, calls, total_exec_time, mean_exec_time, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
This tells you: "These 3 queries are consuming 80% of your CPU/I/O." Fix those, and you fix the database.

Summary: The Complete Tuning Loop
Measure: Use pg_stat_statements to find the slow queries.
Explain: Run EXPLAIN (ANALYZE) on those queries.
Index: Add indexes to remove Seq Scans and Sorts.
Stats: Run ANALYZE if the planner is guessing wrong.
Memory: Tune shared_buffers (global cache) and work_mem (query temp space).
Write-Ahead: Tune max_wal_size and checkpoint_completion_target to smooth out I/O spikes.
Clean: Watch Autovacuum to prevent bloat.
Is this all?
For 90% of production issues, yes. For the last 10%, you dive into:

Locking: Deadlocks, row-level locks, NOWAIT.
Concurrency: Isolation levels (Read Committed vs. Serializable).
Replication: Streaming replication, lag, failover.
Partitioning: Splitting huge tables into chunks.
But if you master the loop above (Measure → Explain → Index → Stats → Memory → WAL → Vacuum), you will handle almost everything.

Your Next Step
Don't try to tune everything at once.

Install pg_stat_statements (if not already).
Find the top 3 slowest queries by total time.
Run EXPLAIN (ANALYZE) on them.
Paste the output here.
I'll tell you exactly which of these components (Index, Stats, Memory, WAL) is the bottleneck for each query.

Yes, this is the final piece of the puzzle. PostgreSQL Storage is the physical reality where Shared Buffers, WAL, MVCC, and Indexes live.

If the previous concepts were "software logic," Storage is the "hardware interaction." Understanding this explains why certain operations are fast and others are slow.

The Core Concept: Files vs. Tables
In many databases, a table is a file. In PostgreSQL, a table is a collection of files.

PostgreSQL does not use a single monolithic file for storage. Instead, it uses a heap file structure.

1. The Heap File (Main Table Storage)
When you create a table, PostgreSQL creates a main file: base/<db_oid>/<table_oid>

Structure: It’s a flat list of Pages (usually 8KB each).
Content: Each page contains Tuples (rows).
MVCC Impact: As we discussed, updates don't overwrite. They append new tuples to the page (or a new page if the old one is full).
Bloat: If you delete rows, the space isn't reclaimed immediately. The page still exists in the file, just marked as having "dead" space.
Key Insight: This is why VACUUM is necessary. It scans these heap files, finds dead tuples, and reclaims space within the pages. It doesn't delete the file; it cleans the pages.

2. Visibility Map (The "Shortcut")
PostgreSQL maintains a hidden file for every table: base/<db_oid>/<table_oid>.vm

Purpose: Tracks which pages in the heap are "clean" (no dead tuples visible to any transaction).
Why it matters: When Autovacuum runs, it checks the Visibility Map first. If a page is marked "clean," Autovacuum skips it. This makes vacuuming much faster than scanning every page.
3. Free Space Map (FSM)
Another hidden file: base/<db_oid>/<table_oid>.fsm

Purpose: Tracks which pages have free space available for new tuples.
Why it matters: When you insert a row, Postgres checks the FSM to find a page with space, rather than scanning all pages. This prevents "page splitting" and keeps inserts efficient.
4. WAL Files (Write-Ahead Log)
Stored in pg_wal/ (or pg_xlog/ in older versions).

Structure: A series of sequential files (8MB each).
Role: As discussed, these record every change before it hits the data files.
Checkpointing: When a checkpoint happens, dirty pages from Shared Buffers are flushed to the Heap Files. The WAL files are then archived or recycled.
5. Index Files
Indexes are stored as separate files, just like tables.

B-Tree Index: Uses a tree structure stored in pages.
File Structure: base/<db_oid>/<index_oid>
Relation to Heap: Each index entry points to a TID (Tuple ID), which is (block_number, tuple_index). This TID tells the Executor exactly where to find the row in the Heap File.
6. TOAST Tables (The "Big Value" Storage)
If a row is too large to fit in an 8KB page (PostgreSQL’s max row size is ~1.6MB), it uses TOAST (The Oversized-Attribute Storage Technique).

What it does: Moves large columns (like TEXT or BYTEA) to a separate "TOAST table."
Storage: The main table row keeps only a short reference (pointer) to the TOAST data.
Compression: TOAST often compresses the data before storing it.
Example:

sql

Copy
CREATE TABLE articles (
    id serial PRIMARY KEY,
    title text,
    body text -- This might go to TOAST
);
If body is 5MB, the main table page holds a pointer, and the 5MB data lives in a separate TOAST heap file.

How Storage Links Everything Together
Component	How it Uses Storage
Shared Buffers	Caches pages from Heap Files and Index Files in RAM.
WAL	Written sequentially to pg_wal/ files. Independent of table files.
Checkpoints	Flush dirty pages from Shared Buffers back to Heap/Index Files on disk.
MVCC	Creates new tuples in Heap Files. Old tuples remain until VACUUM cleans them.
Autovacuum	Scans Heap Files, updates Visibility Map, and reclaims space in FSM.
Index Scan	Traverses Index Files to find TIDs, then fetches rows from Heap Files.
The "Page" is the Unit of Everything
Everything in Postgres revolves around the Page (8KB by default).

Reads: The smallest unit of I/O is one page. Even if you ask for 1 byte, Postgres reads the whole 8KB page into Shared Buffers.
Writes: Changes happen in-page. When the page is dirty, it’s flushed as a whole page.
Indexes: Index entries are packed into pages.
TOAST: Compressed data is stored in TOAST pages.
Tuning Implication:

work_mem: Controls how much memory is used for in-memory sorts/hashes before Postgres spills to temp files on disk.
random_page_cost: Tells the planner how expensive a non-sequential page read is. If you’re on SSD, lower this (to 1.1). If HDD, keep it high (4.0). This affects whether the planner chooses Index Scan vs. Seq Scan.
Summary: The Full Stack
You write SQL.
Parser validates it.
Planner chooses a plan (using Statistics).
Executor runs the plan:
Reads Pages from Heap/Index Files into Shared Buffers.
Uses Index Files to find TIDs.
Fetches rows from Heap Files.
Handles TOAST data if needed.
WAL records every change for durability.
Checkpoints flush dirty pages to disk.
Autovacuum cleans up dead tuples in Heap Files and updates Visibility Map.
Is this all?
Yes. This covers the entire lifecycle of a query in PostgreSQL. If you understand this, you understand why Postgres behaves the way it does.

Next Steps?

Do you want to dive into Performance Tuning (specific config values for postgresql.conf)?
Or Advanced Indexing (Partial Indexes, Expression Indexes, Covering Indexes)?
Or Backup & Recovery (Base Backups, PITR)?
Which path interests you most?