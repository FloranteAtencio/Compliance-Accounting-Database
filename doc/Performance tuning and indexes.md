Step 1: The "Equality First" Rule (Composite Indexes)
When you have multiple columns in a WHERE or ORDER BY, the order in the index matters more than the columns themselves.

The Rule:

Equality columns first (=, IN)
Range columns second (>, <, BETWEEN, LIKE 'prefix%')
Sort columns last (ORDER BY)
Example:

sql

Copy
-- Query: WHERE status = 'active' AND created_at > '2025-01-01' ORDER BY created_at
CREATE INDEX idx_orders_status_created ON orders (status, created_at);
Why?

The index is sorted by status first. It finds all 'active' rows quickly.
Within those 'active' rows, they are already sorted by created_at.
The > range on created_at is efficient because the data is already in order.
Wrong Order:

sql

Copy
-- This index is bad for the query above
CREATE INDEX idx_orders_created_status ON orders (created_at, status);
Postgres would have to scan the whole created_at range, then filter for status = 'active'. Much slower.

Step 2: The "Covering Index" Trick (INCLUDE)
An index scan finds the TID (row location), then Postgres goes back to the main table (the "heap") to fetch the actual row data. This is a random I/O penalty.

If your query only needs columns that are in the index, you can avoid the heap fetch entirely.

sql

Copy
-- Query: SELECT email, name FROM users WHERE id = 123
CREATE INDEX idx_users_id_covering ON users (id) INCLUDE (email, name);
Now the query is an Index Only Scan. It never touches the main table data file.

When to use:

You frequently query a small set of columns that are not the indexed key.
The table is very large, and heap fetches are causing I/O spikes.
Step 3: The "Partial Index" (Filtering)
If you only ever query a subset of your data, index only that subset.

sql

Copy
-- Query: WHERE is_deleted = false
CREATE INDEX idx_users_active ON users (email) WHERE is_deleted = false;
Benefits:

The index is 90% smaller (only active users).
Inserts/updates on deleted users don't touch this index at all (faster writes).
Queries on active users are faster because the index is smaller and fits in cache.
Step 4: The "Expression Index" (Matching the Query)
If your query uses a function on a column, a normal index won't help.

sql

Copy
-- Query: WHERE lower(email) = 'bob@example.com'
CREATE INDEX idx_users_email_lower ON users (lower(email));
Common patterns:

WHERE to_tsvector('english', title) @@ to_tsquery('...') → Use a GIN expression index.
WHERE COALESCE(phone, '') = '...' → Index on COALESCE(phone, '').
Step 5: The "Read-Only" Index (CREATE INDEX CONCURRENTLY)
In production, CREATE INDEX locks the table for writes. If you have a large table, this can cause downtime.

sql

Copy
CREATE INDEX CONCURRENTLY idx_orders_customer ON orders (customer_id);
Trade-off:

It takes longer to build.
It uses more temporary disk space.
It cannot be run inside an explicit transaction block.
Always use this in production.

Step 6: The "Unused Index" Cleanup
Indexes cost money. You should regularly remove them.

sql

Copy
-- Find indexes that have never been used since the last stats reset
SELECT indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND indexrelname NOT LIKE '%_pkey' -- Don't drop PKs!
ORDER BY pg_relation_size(indexrelid) DESC;
Rule: If an index has idx_scan = 0 and is large, drop it. You can always recreate it later if a query needs it.

How to Build an Indexing Plan (Systematic Approach)
Get the slow queries: Use pg_stat_statements to find the top 5 slowest queries.
Run EXPLAIN (ANALYZE): See what they are doing.
Identify the bottleneck:
Seq Scan → Need an index on the WHERE column.
Sort → Need an index on the ORDER BY column.
Hash Join → Need an index on the JOIN column (usually the FK).
Check for redundancy:
Do you have an index on (a) and another on (a, b)? The second one covers the first. Drop the first.
Create with CONCURRENTLY:
CREATE INDEX CONCURRENTLY idx_name ON table (cols);
Verify:
Run the query again. Check EXPLAIN for Index Scan or Index Only Scan.
Advanced: Specialized Index Types
Type	Use Case	Example
B-Tree	Default. Equality, ranges, sorts.	WHERE id = 1
GIN	Arrays, JSONB, Full-text search.	WHERE tags @> ARRAY['urgent']
GiST	Geospatial, Ranges.	PostGIS ST_DWithin
BRIN	Huge tables with natural order (e.g. time-series).	WHERE ts > '2025-01-01' on a log table
BRIN is a game-changer for large tables. If your data is naturally sorted (e.g., by timestamp), a BRIN index can be tiny (KBs) and still speed up range scans significantly.

Final Advice
Start with the basics: B-Tree on WHERE and JOIN columns.
Add INCLUDE if you see Heap Fetches in EXPLAIN.
Add WHERE (Partial) if you query a small subset.
Add CONCURRENTLY in production.
Monitor and remove unused indexes.



Let's do a full diagnostic session. I'll simulate a real-world scenario: you have a slow query, and we'll use EXPLAIN (ANALYZE) to figure out exactly what index to build.

The Scenario
Table: transactions

id: bigint (PK)
account_id: int
amount: numeric
status: varchar ('pending', 'completed', 'failed')
created_at: timestamp
metadata: jsonb
The Slow Query:

sql

Copy
SELECT id, amount, created_at
FROM transactions
WHERE account_id = 42
  AND status = 'completed'
  AND created_at > '2025-01-01'
ORDER BY created_at DESC
LIMIT 50;
Current indexes:

Primary key on id
Index on created_at alone
Step 1: Run EXPLAIN (ANALYZE, BUFFERS)
text

Copy
Limit  (cost=8423.15..8423.27 rows=50 width=22) (actual time=412.3..412.4 rows=50 loops=1)
  Buffers: shared hit=12 read=8943 written=2
  ->  Sort  (cost=8423.15..8456.20 rows=13220 width=22) (actual time=412.3..412.3 rows=50 loops=1)
        Sort Key: created_at DESC
        Sort Method: top-N heapsort  Memory: 35kB
        ->  Bitmap Heap Scan on transactions  (cost=1245.60..7890.40 rows=13220 width=22) (actual time=45.2..398.7 rows=12847 loops=1)
              Recheck Cond: ((status)::text = 'completed'::text)
              Filter: ((account_id = 42) AND (created_at > '2025-01-01 00:00:00'::timestamp))
              Rows Removed by Filter: 84215
              Heap Blocks: exact=8943
              Buffers: shared hit=12 read=8943
              ->  Bitmap Index Scan on idx_transactions_created_at  (cost=134.50..1245.50 rows=15000 width=0) (actual time=42.1..42.1 rows=15000 loops=1)
                    Index Cond: (created_at > '2025-01-01 00:00:00'::timestamp)
                    Buffers: shared read=120

Planning Time: 0.250 ms
Execution Time: 412.5 ms
Step 2: Read the Plan — Bottom-Up Analysis
We start from the bottom (where data is fetched) and work up.

Node 1: Bitmap Index Scan on idx_transactions_created_at
text

Copy
Index Cond: (created_at > '2025-01-01')
rows=15000
Buffers: read=120
What it means:

Postgres used your existing created_at index.
It found 15,000 rows with created_at > '2025-01-01'.
This part is fast (42ms).
Problem: 15,000 rows is too many. We need only ~50.

Node 2: Bitmap Heap Scan on transactions
text

Copy
Filter: (account_id = 42) AND (created_at > ...)
Rows Removed by Filter: 84215
Heap Blocks: exact=8943
Buffers: read=8943
This is the bottleneck.

Metric	Value	Meaning
Rows Removed by Filter	84,215	Scanned 84K extra rows just to throw them away
Heap Blocks: exact=8943	8,943 pages read	Random I/O to fetch actual row data
Buffers: read=8943	8,943 disk reads	Most were not in cache → slow
Why this happened: The index only filtered by created_at. Now Postgres must go to the main table (heap) for all 15,000 rows, check account_id = 42, and discard non-matches. That's expensive random I/O.

Node 3: Sort
text

Copy
Sort Key: created_at DESC
Sort Method: top-N heapsort  Memory: 35kB
Postgres had to sort 12,847 matching rows down to the top 50. Not terrible (it fits in memory), but unnecessary if the index could provide pre-sorted data.

Node 4: Limit
Just takes the first 50 rows after sorting.

Step 3: Diagnose the Root Cause
Problem	Evidence	Fix
Too many rows scanned	Rows Removed by Filter: 84215	Need an index that includes account_id and status
Random heap I/O	Buffers: read=8943	Covering index would eliminate heap fetches
Unnecessary sort	Sort node present	Index should match ORDER BY created_at DESC
Step 4: Build the Index
Apply the rules:

Equality columns first: account_id, status
Range/sort column next: created_at
Covering columns (INCLUDE): id, amount (so we never touch the heap)
sql

Copy
CREATE INDEX CONCURRENTLY idx_txn_account_status_created
ON transactions (account_id, status, created_at DESC)
INCLUDE (id, amount);
Why this order?

account_id = 42 → equality, narrows to one customer's slice
status = 'completed' → equality, further narrows within that customer
created_at DESC → range + sort. Since the index is already sorted by created_at DESC within each (account_id, status) group, no separate Sort node needed.
Step 5: Verify With EXPLAIN Again
text

Copy
Limit  (cost=0.42..2.15 rows=50 width=22) (actual time=0.05..0.12 rows=50 loops=1)
  Buffers: shared hit=8
  ->  Index Only Scan using idx_txn_account_status_created on transactions
        (cost=0.42..5.80 rows=132 width=22) (actual time=0.05..0.10 rows=50 loops=1)
        Index Cond: ((account_id = 42) AND (status = 'completed') AND (created_at > '2025-01-01'))
        Heap Fetches: 0
        Buffers: shared hit=8

Planning Time: 0.180 ms
Execution Time: 0.15 ms
Before vs After Comparison
Metric	Before	After	Improvement
Execution Time	412.5 ms	0.15 ms	~2750x faster
Disk Reads (Buffers)	8,943	8	~1100x less I/O
Rows Scanned	12,847 (+84K discarded)	50	Exact match
Sort Required?	Yes (top-N heapsort)	No (index pre-sorted)	Eliminated
Heap Fetches	8,943 page reads	0 (Index Only Scan)	Eliminated
Cost Estimate	8,423	2.15	Planner confidence way up
What Changed and Why
Change	Effect
Added account_id, status as leading columns	Filtered at the index level instead of post-filtering 84K rows
Made created_at DESC part of the key	Eliminated the Sort node entirely
Used INCLUDE (id, amount)	Enabled Index Only Scan → zero heap fetches
Result: Heap Fetches: 0	Query touches only 8 index pages total
Your Diagnostic Checklist
When you see any EXPLAIN (ANALYZE) output, scan for these red flags:


 Seq Scan → Missing index on WHERE column

 Rows Removed by Filter: <large number> → Index doesn't cover enough predicates

 Sort node → Index doesn't match ORDER BY

 High Buffers: read= → Random I/O; consider covering index or caching

 Heap Fetches > 0 on Index Only Scan → Run VACUUM to update Visibility Map

 rows=X vs actual rows=Y mismatch → Statistics stale; run ANALYZE

 loops=N where N > 1 → Nested loop running inner scan many times; may need different join strategy
Want to try this yourself? Paste any real EXPLAIN (ANALYZE) output from your database and I'll walk through it with you step-by-step, just like this example.