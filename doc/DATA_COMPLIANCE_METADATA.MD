docs.compliance = `# Compliance Metadata Schema

**Schema:** \`Finance\` · **Tables:** 11 · **Layer:** Level 6 — Privacy Principles

## Purpose

This schema stores compliance facts about data, not the data itself. It answers four questions at query time:

1. How sensitive is this table or column?
2. How long must we keep it?
3. Is PII present, and under which regulation?
4. Who is accountable for it?

Every other control in this platform reads from these tables before acting.

## Tables

| Table | Role | Key constraint |
|---|---|---|
| \`compliance_metadata\` | Table-level classification and retention assignment | \`UNIQUE(table_name)\` |
| \`column_classification\` | Column-level PII, financial, encryption, masking flags | \`UNIQUE(table_name, column_name)\` |
| \`event_log_enhanced\` | Operation log with compliance level and hash chain | \`UNIQUE(idempotency_key)\` |
| \`audit_trail\` | Before/after state for financial transactions | FK to \`transactions\`, no cascade delete |
| \`data_access_log\` | Who read what, granted or denied, and why | indexed on user, table, time |
| \`encryption_keys\` | Field-level key registry and rotation schedule | \`UNIQUE(table_name, column_name)\` |
| \`retention_policy\` | Archive location, delete method, purge dates | \`UNIQUE(table_name)\` |
| \`pii_consent\` | Consent grants and withdrawals per client | versioned consent text |
| \`compliance_checklist\` | Framework requirement tracking (GDPR, PH-PDPA, ISO 27001) | status + evidence pointer |
| \`security_incident\` | Incident record, severity, notification timing | array of affected tables |
| \`bulk_operations_audit\` | Bulk import/export governance | export encryption flag |

## Enumerated types

\`\`\`text
data_classification_enum : PUBLIC | INTERNAL | CONFIDENTIAL | SENSITIVE
retention_period_enum    : PERMANENT | 7_YEARS | 5_YEARS | 3_YEARS | 1_YEAR | 90_DAYS | 30_DAYS
\`\`\`

Enum labels are strict. A value of \`7 YEARS\` or \`seven_years\` fails at load time.

## Design decisions worth noting

- **Metadata is data.** Classification lives in rows, so policies change without DDL migrations.
- **Table and column classification are separate.** A table can be \`CONFIDENTIAL\` while one column inside it is \`SENSITIVE\`. Coarse-grained classification alone hides risk.
- **\`hash_chain\` on the event log** supports tamper detection. Each row references the previous digest.
- **Consent carries a version string.** This proves which policy text a client agreed to, which is the part regulators actually ask for.
- **\`ON DELETE NO ACTION\` on audit FKs.** Financial records cannot be deleted out from under their own audit trail.

## Sample queries

Which columns require masking?

\`\`\`sql
SELECT table_name, column_name, description
FROM   Finance.column_classification
WHERE  masking_required;
\`\`\`

Which tables hold PII and fall under PH-PDPA?

\`\`\`sql
SELECT table_name, data_steward, retention_period
FROM   Finance.compliance_metadata
WHERE  pii_present AND ph_pdata_applicable;
\`\`\`

Recent access to restricted tables by role:

\`\`\`sql
SELECT user_role, table_name, count(*) AS accesses,
       max(created_at) AS last_seen
FROM   Finance.data_access_log
WHERE  created_at > now() - interval '30 days'
GROUP  BY user_role, table_name
ORDER  BY accesses DESC;
\`\`\`

## Known gaps

- No history table for steward reassignment. \`updated_at\` overwrites the prior value.
- \`gdpr_applicable\` and \`ph_pdata_applicable\` are booleans. Multi-framework scope would be cleaner as a join table.
- \`encryption_keys\` stores metadata only. Actual key material must live outside the database.
`;

docs.lifecycle = `# Data Lifecycle & Retention Policy Schema

**Schema:** \`Finance\` · **Tables:** 9 · **Layer:** Level 4 — Lifecycle Implementation

## Purpose

This schema automates what happens to data over time. It defines how long records live, when they move to cheaper storage, when they may be deleted, and what stops deletion early.

It also records proof that each action happened, which is what auditors request.

## The lifecycle model

\`\`\`text
ACTIVE  ->  WARM_STORAGE  ->  COLD_STORAGE  ->  SCHEDULED_DELETE  ->  DELETED
   |
   +-- LEGAL HOLD freezes the entire chain
\`\`\`

Two independent clocks drive transitions:

- \`archive_after_days\` — moves data off the hot path
- \`retention_period_days\` — permits destruction

Financial data archives at 365 days but is not eligible for deletion until 2555 days. Separating these prevents premature loss.

## Tables

| Table | Role |
|---|---|
| \`data_retention_policy\` | Per-table rules: period, archive trigger, delete method, soft-delete column |
| \`data_lifecycle_events\` | Every transition attempt with duration, status, error, rollback flag |
| \`archive_metadata\` | Archive inventory: size, format, compression, checksum, purge eligibility |
| \`deleted_records_tracking\` | Soft-deleted rows with recoverability and hard-delete date |
| \`lifecycle_schedule\` | When policies run, timezone-aware, with notification target |
| \`retention_exceptions\` | Record-level holds for litigation, regulatory, audit reasons |
| \`lifecycle_lineage\` | Stage history per record, plus parent-record linkage |
| \`compliance_hold\` | Named holds covering multiple tables with legal reference |
| \`purge_execution_log\` | Counts processed, archived, deleted, failed; backup verification result |

## Enumerated type

\`\`\`text
retention_action_enum : ACTIVE | WARM_STORAGE | COLD_STORAGE | SCHEDULED_DELETE | DELETED
\`\`\`

## Delete strategies

| Method | Use case | Behaviour |
|---|---|---|
| \`ARCHIVE_ONLY\` | Financial records under statutory retention | Move to archive table, never destroy |
| \`SOFT_DELETE\` | Customer data subject to erasure requests | Flag via \`soft_delete_column\`, retain for recovery window |
| \`HARD_DELETE\` | Expired logs below evidentiary value | Physical removal after backup verification |

The policy table names its own soft-delete column, so one engine handles heterogeneous schemas without per-table code.

## Safety controls already modeled

- **Legal hold precedence.** \`compliance_hold\` and \`retention_exceptions\` both block purge. Two levels: table-wide and record-specific.
- **Backup verification gate.** \`purge_execution_log.backup_verification_passed\` must be true before counts are accepted.
- **Pre/post row counts.** \`pre_purge_record_count\` and \`post_purge_record_count\` make silent over-deletion detectable.
- **Approval fields on purge.** \`approval_required\`, \`approved_by\`, \`approved_at\` support segregation of duties.
- **Checksum on archives.** Detects corruption before someone needs a restore.

## Populated policy summary

| Category | Retention | Example tables |
|---|---|---|
| Financial | 2555 days (7y) | transactions, journals, AR/AP and extensions |
| Operational | 1095 days (3y) | inventory audits, transfers, returns |
| Customer | 1825 days (5y), soft delete | customers |
| Reference / master | PERMANENT | clients, charts, products, warehouses |
| Logs | 2555 days | event_log |

## Sample query

What is due for archival in the next 30 days?

\`\`\`sql
SELECT p.table_name, p.archive_table_name, p.next_archive_date,
       h.hold_name
FROM   Finance.data_retention_policy p
LEFT   JOIN Finance.compliance_hold h
       ON h.is_active AND p.table_name = ANY(h.affected_tables)
WHERE  p.is_enabled
  AND  p.next_archive_date BETWEEN current_date AND current_date + 30
ORDER  BY p.next_archive_date;
\`\`\`

## Known gaps

- Scheduler stores intent; execution still requires an external runner (pg_cron or Python).
- No dry-run mode recorded in \`purge_execution_log\`.
- \`archive_size_mb\` is numeric but unvalidated against actual file size.
`;

docs.governance = `# Data Governance Metadata Schema

**Schema:** \`governance_v2\` · **Tables:** 9 · **Layer:** Level 8 — Data Governance

## Purpose

This schema models accountability and access policy. It answers who owns a field, how sensitive it is, what handling it demands, and which roles may touch it.

It is the control layer. The compliance and lifecycle schemas act on data; this one decides whether they are permitted to.

## Entity relationships

\`\`\`text
domains --+--> owners ----+
          |               |
          +--------------> catalog <---- sensitivity
          |               |                |
custodians ---------------+                +-- column_classification (1:1)
                          |
                          +-- handling  (scoped to a level OR a column)
roles ----------------------> access_matrix <--- domains
\`\`\`

## Tables

| Table | Role | Notable constraint |
|---|---|---|
| \`domains\` | Business subject areas | \`domain_name\` unique |
| \`owners\` | Business-side accountability | \`UNIQUE(role_title, domain_id)\` |
| \`custodians\` | Technical stewards | \`role_title\` unique |
| \`catalog\` | Column-level register with purpose and ownership | all FKs NOT NULL; natural key unique |
| \`sensitivity\` | Levels plus PII type | CHECK on level values |
| \`column_classification\` | Links catalog entry to one sensitivity level | PK is \`catalog_id\` |
| \`handling\` | Required controls | CHECK forces exactly one scope anchor |
| \`roles\` | Access principals | \`role_name\` unique |
| \`access_matrix\` | Role × domain permission, with explicit deny | composite PK |

## Three design decisions that matter

**1. Enforced single classification.** \`column_classification\` uses \`catalog_id\` as primary key. A column cannot carry two sensitivity levels simultaneously. Ambiguity is structurally impossible.

**2. Handling rules inherit or override.** A rule anchored to \`sensitivity_id\` applies to every column at that level. A rule anchored to \`catalog_id\` applies to one column. The CHECK constraint guarantees every rule has exactly one anchor, so evaluation order stays predictable.

**3. Explicit deny with reason.** \`access_matrix.denied_at\` plus \`reason\` records refusals rather than leaving them implicit. Absence of a row means no grant; presence of a denial means someone decided and documented why. That distinction is what makes the matrix auditable.

## Sensitivity ladder

| Level | PII | Typical handling |
|---|---|---|
| Internal | No | Standard backup and retention |
| Confidential | Yes, individual | Encryption at rest, audit logging, no personal-device export |
| Restricted | Yes, individual or org | Encryption in transit too, no email transmission, deletion on request |

## Current population

- 2 domains: Finance, Operations
- 4 business owner roles, 1 custodian role
- 3 sensitivity levels
- 3 catalogued columns on \`Finance.clients\`
- 10 handling rules, 1 column-scoped override
- 9 roles across 2 domains, including an explicit deny for External Accountant on Finance

## Enforcement gap

The matrix is currently descriptive. Nothing reads it to produce a real restriction. Closing this converts documentation into a control.

Target function signature:

\`\`\`sql
CREATE FUNCTION governance_v2.generate_rls_policies(
    p_schema TEXT,
    p_table  TEXT
) RETURNS TEXT;
\`\`\`

It joins \`access_matrix\` → \`domains\` → \`catalog\` → \`column_classification\` → \`sensitivity\`, then emits \`CREATE POLICY\` and masked-view statements per role. Generated output belongs in the repo so reviewers can see the control working end to end.

## Known gaps

- No ownership history. Reassignment overwrites the previous owner.
- No policy versioning. Editing a handling rule destroys the prior state, which breaks retroactive compliance proof.
- \`sensitivity.level\` is TEXT with CHECK while sibling schemas use ENUM. Inconsistent typing.
- Overlaps with \`Finance.compliance_metadata\` and \`Finance.column_classification\`. One source of truth is needed.
`;

