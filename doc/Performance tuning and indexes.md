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