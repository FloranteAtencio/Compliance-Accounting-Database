Purpose
↓
Components
↓
Data Flow
↓
Controls
↓
Evidence

1. Governance Purpose

Data Discovery
↓
Data Classification
↓
Handling Policies
↓
Access Control Rules
↓
Operational Enforcement
↓
Monitoring & Evidence Collection

Purpose

To ensure organizational data is properly identified, classified, protected, monitored, retained, and governed throughout its lifecycle.

2. Audit & Lineage Layer
Staging Layer Audit Controls
Component	                    Purpose
Audit.import_sessions	        Tracks batch import sessions
Audit.import_validation_log	    Records validation results during import
Audit.import_detail_logs	    Tracks row-level import success/failure
Audit.import_workflows	        Tracks workflow status changes
Audit.import_approvals	        Tracks approval decisions before 

production loading
Objective

Provide traceability from source file to staging records before production loading.

Production Layer Audit Controls
Component	                    Purpose
Audit.audit_logs	            Records INSERT, UPDATE and DELETE activities
Audit.audit_logs_extended	    Field-level change tracking
Audit.record_lineage	        Tracks record origin and modification history
Audit.transaction_lifecycle	    Tracks transaction status progression
Audit.approval_chain	        Tracks approval workflow
Audit.reconciliation_tracking	Tracks reconciliation process

Production layer export data management

Component	                        Purpose

management.data_exports             Trail of data exported
management.vendor_registry          from 
management.data_residency           foriegn 
management.data_export_metadata     source
management.cross_border_transfer

management.dataset_data_subjects    Logs or metadata
management.data_inventory           policies and jurisdiction
management.privacy_policies         
management.dataset_policy_map
management.jurisdiction_mapping

management.security_controls
management.risk_register
management.incident_response
management.controls_evidence

Objective
Provide accountability,
auditability,
and historical traceability
for production transactions.


3. Data Ownership Model

Cross-Border Data Governance

The platform must be able to answer:

What data was transferred?
 
Who approved the transfer?
 
Who received the data?
 
Which country received the data?
 
Which policy governed the transfer?
 
What controls protected the data?
 
What evidence exists for the transfer?
Show more lines

4. Data Flow

Customer
↓
country
↓
policy
↓
trail and logs
↓
control
↓
enforcement
``

Data Lifecycle Flow

Customer / Data Subject
↓
Collection
↓
Country / Jurisdiction
↓
Classification
↓
Governance Policy
↓
Access Control
↓
System Processing
↓
Audit & Lineage
↓
Retention & Compliance
↓
Evidence & Monitoring

5. The Strongest Architecture Statement

Data
↓
Catalog
↓
Classification
↓
Ownership
↓
Policy
↓
Access Control
↓
Audit & Lineage
↓
Compliance
↓
Retention
↓
Incident Response
↓
Evidence

Key Questions Answered
What data exists?
Who owns it?
How sensitive is it?
Who can access it?
Who changed it?
Where did it originate?
Where did it move?
How long should it be kept?
When should it be deleted?
What evidence exists?

DATA
 │
 ├── What is it?
 │      → Catalog
 │
 ├── How sensitive is it?
 │      → Classification
 │
 ├── Who owns it?
 │      → Ownership
 │
 ├── Who technically manages it?
 │      → Custodian
 │
 ├── Who may access it?
 │      → Access model
 │
 ├── How should it be handled?
 │      → Handling rules
 │
 └── What quality/format should it follow?
        → Data standards

That's a much clearer architecture.

Your governance_v2 is basically becoming this:

                    GOVERNANCE V2
                         │
        ┌────────────────┼─────────────────┐
        │                │                 │
      DATA             PEOPLE           RULES
        │                │                 │
        ▼                ▼                 ▼
    Catalog           Owners          Handling
    Domains           Custodians      Standards
    Classification    Roles
                       │
                       ▼
                    Access
                       │
                       ▼
                 Access Reviews

And then this governance layer sits above your actual database:

                 GOVERNANCE LAYER
                         │
        ┌────────────────┼─────────────────┐
        │                │                 │
     Catalog          Policies          Access
     Metadata         Rules             Decisions
        │                │                 │
        └────────────────┼─────────────────┘
                         │
                         ▼
                 DATABASE ENGINEERING
                         │
        ┌────────────────┼─────────────────┐
        │                │                 │
       RBAC             RLS              CLS
        │                │                 │
      Views          Encryption        Audit
        │                │                 │
        └────────────────┼─────────────────┘
                         ▼
                    Finance DB

This is the architecture part you were sensing.

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