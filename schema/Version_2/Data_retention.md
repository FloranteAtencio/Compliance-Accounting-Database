## 3. Retention & Deletion Engine

**Purpose:** Enforce legal deletion timelines and produce 
evidence that data was destroyed as required.

**Scope:** This module does NOT track lineage or audit trails 
(handled by Audit.record_lineage). It tracks only:
- What the retention rule is
- Whether data was archived or deleted
- Exceptions that blocked deletion

Component	                Purpose
data_retention_policy	    Declares how long each table's data lives (authoritative source)
archive_metadata	        Proves archived data exists, is intact (checksum), and encrypted
retention_exceptions	    Record-level holds that block purge (legal, litigation)
compliance_hold	            Table-level freezes for investigations
purge_execution_log	        Evidence that deletion ran: counts before/after, approval, result


Data lifecycle
... → Retention & Compliance → Evidence & Monitoring
                                    ↑
                    purge_execution_log + archive_metadata


Question answered:

Question	                Evidence Source
How long should it be kept?	Finance.data_retention_policy
When should it be deleted?	data_retention_policy.next_deletion_date
Was it actually deleted?	Finance.purge_execution_log