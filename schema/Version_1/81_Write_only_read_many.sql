BEGIN;

-- ═══════════════════════════════════════════
-- 1. WORM Functions
-- ═══════════════════════════════════════════

CREATE OR REPLACE FUNCTION audit.worm_strict()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'WORM Violation: % on %.% is prohibited',
        TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME
        USING ERRCODE = 'insufficient_privilege',
              HINT = 'Audit tables are immutable.';
    RETURN NULL;
END;
$$ SECURITY DEFINER SET search_path = finance, audit, compliance, staging, pg_catalog;

-- Secure override: requires BOTH a GUC flag AND a valid approval record
CREATE OR REPLACE FUNCTION audit.worm_with_exception()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_permission TEXT;
    v_approved   BOOLEAN;
BEGIN
    v_permission := current_setting('app.worm_override', true);

    IF v_permission IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'WORM Override Required for %.%',
            TG_TABLE_SCHEMA, TG_TABLE_NAME
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Verify a real approval exists (not just a session variable)
    SELECT EXISTS (
        SELECT 1 FROM audit.worm_approvals
        WHERE table_name = TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME
          AND approver   = current_setting('app.worm_approver', true)
          AND approved_at > now() - interval '15 minutes'
          AND used = FALSE
    ) INTO v_approved;

    IF NOT v_approved THEN
        RAISE EXCEPTION 'WORM Override rejected: no valid approval for %.%',
            TG_TABLE_SCHEMA, TG_TABLE_NAME
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Mark approval as consumed (single-use token)
    UPDATE audit.worm_approvals
    SET used = TRUE, used_at = now(), used_by = current_user
    WHERE table_name = TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME
      AND approver   = current_setting('app.worm_approver', true)
      AND used = FALSE;

    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ SECURITY DEFINER SET search_path = finance, audit, compliance, staging, pg_catalog;

-- ═══════════════════════════════════════════
-- 2. Approval Registry
-- ═══════════════════════════════════════════

CREATE TABLE IF NOT EXISTS audit.worm_approvals (
    approval_id  SERIAL PRIMARY KEY,
    table_name   TEXT        NOT NULL,
    reason       TEXT        NOT NULL,
    approver     TEXT        NOT NULL,
    requested_by TEXT        NOT NULL DEFAULT current_user,
    approved_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at   TIMESTAMPTZ NOT NULL DEFAULT now() + interval '15 minutes',
    used         BOOLEAN     NOT NULL DEFAULT FALSE,
    used_at      TIMESTAMPTZ,
    used_by      TEXT
);

-- ═══════════════════════════════════════════
-- 3. Attach Triggers (Single Source of Truth)
-- ═══════════════════════════════════════════

DO $$
DECLARE
    t TEXT;
    strict_tables TEXT[] := ARRAY[
        'audit.record_lineage',
        'audit.audit_logs',
        'audit.audit_logs_extended',
        'audit.import_detail_logs',
        'audit.reconciliation_tracking',
        'audit.approval_chain',
        'audit.transaction_lifecycle',
        'compliance.compliance_logs',
        'compliance.compliance_rules'
    ];
    exception_tables TEXT[] := ARRAY[
        'audit.import_sessions'
     
    ];
--    'audit.import_validation_log'
BEGIN
    -- Strict: no override possible
    FOREACH t IN ARRAY strict_tables LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS guard_worm ON %s;
             CREATE TRIGGER guard_worm
             BEFORE UPDATE OR DELETE ON %s
             FOR EACH ROW EXECUTE FUNCTION audit.worm_strict();',
            t, t
        );
    END LOOP;

    -- Exception: override requires approval record
    FOREACH t IN ARRAY exception_tables LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS guard_worm ON %s;
             CREATE TRIGGER guard_worm
             BEFORE UPDATE OR DELETE ON %s
             FOR EACH ROW EXECUTE FUNCTION audit.worm_with_exception();',
            t, t
        );
    END LOOP;
END $$;

-- ═══════════════════════════════════════════
-- 4. Block TRUNCATE (triggers don't fire on TRUNCATE)
-- ═══════════════════════════════════════════

DO $$
DECLARE
    t TEXT;
    all_tables TEXT[] := ARRAY[
        'audit.record_lineage','audit.audit_logs','audit.audit_logs_extended',
        'audit.import_detail_logs','audit.reconciliation_tracking',
        'audit.approval_chain','audit.transaction_lifecycle',
        'compliance.compliance_logs','compliance.compliance_rules',
        'audit.import_sessions','audit.import_validation_log'
    ];
BEGIN
    FOREACH t IN ARRAY all_tables LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS guard_worm_truncate ON %s;
             CREATE TRIGGER guard_worm_truncate
             BEFORE TRUNCATE ON %s
             FOR EACH STATEMENT EXECUTE FUNCTION audit.worm_strict();',
            t, t
        );
    END LOOP;
END $$;

-- ═══════════════════════════════════════════
-- 5. Append-Only Optimization
-- ═══════════════════════════════════════════

ALTER TABLE audit.audit_logs SET (fillfactor = 100);

-- ═══════════════════════════════════════════
-- 6. Hash Chain Verification
-- ═══════════════════════════════════════════

CREATE OR REPLACE FUNCTION audit.verify_audit_chain()
RETURNS TABLE(
    row_id         INT,
    is_valid       BOOLEAN,
    expected_hash  TEXT,
    actual_prev_hash TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = audit, pg_catalog
AS $$
BEGIN
    RETURN QUERY
    WITH chain AS (
        SELECT
            audit_id,
            row_hash,
            prev_hash,
            LAG(row_hash) OVER (ORDER BY audit_id) AS last_row_hash
        FROM audit.audit_logs
    )
    SELECT
        audit_id::INT,
        CASE
            WHEN audit_id = (SELECT min(audit_id) FROM audit.audit_logs)
                THEN prev_hash IS NULL          -- genesis must have no prev
            ELSE prev_hash = last_row_hash       -- all others must chain
        END,
        last_row_hash,
        prev_hash
    FROM chain
    ORDER BY audit_id;
END;
$$;

COMMIT;

SELECT 'WORM v2 deployed' AS status;

-- BEGIN;

--     CREATE OR REPLACE FUNCTION Audit.WORM()
--     RETURNS TRIGGER
--     LANGUAGE plpgsql
--     AS $$
--     BEGIN

--     RAISE EXCEPTION 'Direct Operation of Update and Delete is Prohibited';

--     IF TG_OP = 'DELETE' THEN   
--         RETURN OLD;
--     ELSE
--         RETURN NEW;
--     END IF;

--     END;
--     $$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;

--     CREATE TRIGGER Guard_worms
--     BEFORE UPDATE OR DELETE ON Audit.record_lineage
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_audit_logs
--     BEFORE UPDATE OR DELETE ON Audit.audit_logs
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_audit_log_extended
--     BEFORE UPDATE OR DELETE ON Audit.audit_logs_extended
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_import_detail_logs
--     BEFORE UPDATE OR DELETE ON Audit.import_detail_logs
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_compliance_logs
--     BEFORE UPDATE OR DELETE ON Compliance.compliance_logs
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_compliance_rules
--     BEFORE UPDATE OR DELETE ON Compliance.compliance_rules
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_reconciliation_tracking
--     BEFORE UPDATE OR DELETE ON Audit.reconciliation_tracking
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_approval_chain
--     BEFORE UPDATE OR DELETE ON Audit.approval_chain
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_transaction_lifecycle
--     BEFORE UPDATE OR DELETE ON Audit.transaction_lifecycle
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guar_worms_import_validation_log
--     BEFORE UPDATE OR DELETE ON Audit.import_validation_log
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_import_session
--     BEFORE DELETE ON Audit.import_sessions
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();


-- -- 1. Core WORM Function (Strict Mode)
-- CREATE OR REPLACE FUNCTION audit.worm_strict()
-- RETURNS TRIGGER
-- LANGUAGE plpgsql
-- -- SECURITY DEFINER
-- -- SET search_path = finance, audit, compliance, security, staging, pg_catalog
-- AS $$
-- BEGIN
--     RAISE EXCEPTION 'WORM Violation: Cannot modify audit records via % on %.%',
--         TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME
--         USING ERRCODE = 'insufficient_privilege',
--               HINT = 'Audit tables are immutable. Use the exception mechanism if authorized.';
--     RETURN NULL; -- Unreachable, but required
-- END;
-- $$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;


-- -- 2. WORM Function with Exception Check
-- CREATE OR REPLACE FUNCTION audit.worm_with_exception()
-- RETURNS TRIGGER
-- LANGUAGE plpgsql
-- -- SECURITY DEFINER
-- -- SET search_path = finance, audit, compliance, security, staging, pg_catalog
-- AS $$
-- DECLARE
--     v_permission TEXT;
-- BEGIN
--     -- Check for explicit permission flag
--     v_permission := current_setting('app.worm_override', true);

--     IF v_permission IS DISTINCT FROM 'true' THEN
--         RAISE EXCEPTION 'WORM Override Required: Set app.worm_override = ''true'' to bypass.',
--             USING ERRCODE = 'insufficient_privilege',
--                   HINT = 'This is for approved corrections only. Requires audit trail entry.';
--     END IF;

--     -- If permission exists, allow the operation
--     IF TG_OP = 'DELETE' THEN
--         RETURN OLD;
--     ELSE
--         RETURN NEW;
--     END IF;
-- END;
-- $$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;


-- -- 3. Create Triggers on Immutable Tables (Strict)
-- DO $$
-- DECLARE
--     t TEXT;
--     tbls TEXT[] := ARRAY[
--         'Audit.record_lineage',
--         'Audit.audit_logs',
--         'Audit.audit_logs_extended',
--         'Audit.import_detail_logs',
--         'Audit.reconciliation_tracking',
--         'Audit.approval_chain',
--         'Audit.transaction_lifecycle'
--     ];
-- BEGIN
--     FOR t IN SELECT unnest(tbls) LOOP
--         EXECUTE format('
--             CREATE TRIGGER guard_worm_strict_%s
--             BEFORE UPDATE OR DELETE ON %s
--             FOR EACH ROW EXECUTE FUNCTION audit.worm_strict();
--         ', 
--             regexp_replace(t, '^[^.]+\.(.+)', '\1', 'i'), -- Extract table name
--             t
--         );
--     END LOOP;
-- END $$;

-- -- 4. Create Triggers on Tables with Exception Logic
-- DO $$
-- BEGIN
--     CREATE TRIGGER guard_worm_session_update
--         BEFORE UPDATE ON Audit.import_sessions
--         FOR EACH ROW EXECUTE FUNCTION audit.worm_with_exception();

--     CREATE TRIGGER guard_worm_import_validation
--         BEFORE UPDATE ON Audit.import_validation_log
--         FOR EACH ROW EXECUTE FUNCTION audit.worm_with_exception();

--     CREATE TRIGGER guard_worm_compliance_logs
--         BEFORE UPDATE OR DELETE ON Compliance.compliance_logs
--         FOR EACH ROW EXECUTE FUNCTION audit.worm_strict();

--     CREATE TRIGGER guard_worm_compliance_rules
--         BEFORE UPDATE OR DELETE ON Compliance.compliance_rules
--         FOR EACH ROW EXECUTE FUNCTION audit.worm_strict();

--     CREATE TRIGGER guard_worm_import_sessions_delete
--         BEFORE DELETE ON Audit.import_sessions
--         FOR EACH ROW EXECUTE FUNCTION audit.worm_strict();
-- END $$;


-- -- 1. Enforce Append-Only Behavior
-- ALTER TABLE Audit.audit_logs SET (fillfactor = 100);
-- ALTER TABLE Audit.audit_logs SET (autovacuum_enabled = false); -- Optional: reduce churn

-- -- 2. Improved Hash Chain Verification
-- CREATE OR REPLACE FUNCTION audit.verify_audit_chain()
-- RETURNS TABLE(
--     row_id INT,
--     is_valid BOOLEAN,
--     broken_at_row INT,
--     expected_hash TEXT,
--     actual_prev_hash TEXT
-- )
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- SET search_path = audit, pg_catalog
-- AS $$
-- BEGIN
--     RETURN QUERY
--     WITH chain AS (
--         SELECT 
--             audit_id,
--             row_hash,
--             prev_hash,
--             LAG(row_hash) OVER (ORDER BY audit_id, audit_id) as last_row_hash
--         FROM Audit.audit_logs
--     )
--     SELECT 
--         audit_id AS row_id,
--         (audit_id = 1) OR (prev_hash = last_row_hash) AS is_valid,
--         CASE 
--             WHEN NOT ((audit_id = 1) OR (prev_hash = last_row_hash)) THEN audit_id 
--             ELSE NULL 
--         END AS broken_at_row,
--         last_row_hash AS expected_hash,
--         prev_hash AS actual_prev_hash
--     FROM chain
--     WHERE audit_id > 1 OR (audit_id = 1 AND (audit_id = 1 AND prev_hash IS NOT NULL)); -- Adjust logic as needed
-- END;
-- $$;
-- 3. Periodic Integrity Check (Run via cron/pgagent)
-- SELECT * FROM audit.verify_audit_chain() WHERE broken_at_row IS NOT NULL;
--     CREATE OR REPLACE FUNCTION Audit.WORM()
--     RETURNS TRIGGER
--     LANGUAGE plpgsql
--     AS $$
--     BEGIN
--     RAISE EXCEPTION 'Direct Operation of Update and Delete is Prohibited';
--     IF TG_OP = 'DELETE' THEN   
--         RETURN OLD;
--     ELSE
--         RETURN NEW;
--     END IF;

--     END;
--     $$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;

--     CREATE TRIGGER Guard_worms
--     BEFORE UPDATE OR DELETE ON Audit.record_lineage
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_audit_logs
--     BEFORE UPDATE OR DELETE ON Audit.audit_logs
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_audit_log_extended
--     BEFORE UPDATE OR DELETE ON Audit.audit_logs_extended
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_import_detail_logs
--     BEFORE UPDATE OR DELETE ON Audit.import_detail_logs
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_compliance_logs
--     BEFORE UPDATE OR DELETE ON Compliance.compliance_logs
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_compliance_rules
--     BEFORE UPDATE OR DELETE ON Compliance.compliance_rules
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_reconciliation_tracking
--     BEFORE UPDATE OR DELETE ON Audit.reconciliation_tracking
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_approval_chain
--     BEFORE UPDATE OR DELETE ON Audit.approval_chain
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_transaction_lifecycle
--     BEFORE UPDATE OR DELETE ON Audit.transaction_lifecycle
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guar_worms_import_validation_log
--     BEFORE UPDATE OR DELETE ON Audit.import_validation_log
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE TRIGGER Guard_worms_import_session
--     BEFORE DELETE ON Audit.import_sessions
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM();

--     CREATE OR REPLACE FUNCTION Audit.WORM_exceptions()
--     RETURNS TRIGGER
--     LANGUAGE plpgsql
--     AS $$
--     BEGIN

--         IF current_setting('app.get_permission_to_update', true) IS NULL THEN
        
--             RAISE EXCEPTION 'Direct Operation of Update and Delete is Prohibited';
        
--         END IF;

--     IF TG_OP = 'DELETE' THEN   
--         RETURN OLD;
--     ELSE
--         RETURN NEW;
--     END IF;

--     END;
--     $$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;

--     CREATE TRIGGER Guar_worms_import_validation_log_exceptions
--     BEFORE UPDATE ON Audit.import_sessions
--     FOR EACH ROW EXECUTE FUNCTION Audit.WORM_exceptions();

-- COMMIT;

-- -- ✅ Make audit tables APPEND-ONLY
-- ALTER TABLE Audit.audit_logs SET (fillfactor = 100);  -- Never update

-- -- ✅ Add constraint: no UPDATEs or DELETEs
-- CREATE TRIGGER audit_logs_immutable
-- BEFORE UPDATE OR DELETE ON Audit.audit_logs
-- FOR EACH ROW EXECUTE FUNCTION raise_exception('Audit logs cannot be modified');

-- -- ✅ For extra security: Hash chain (you already have this!)
-- -- Your code shows:
-- -- prev_hash, row_hash columns
-- -- This is good, but verify the hash is SHA-256 and chain validation runs

-- -- ✅ Implement hash verification:
-- CREATE OR REPLACE FUNCTION Audit.verify_audit_chain()
-- RETURNS TABLE(row_id INT, is_valid BOOLEAN, broken_at_row INT) AS $$
-- BEGIN
--     RETURN QUERY
--     WITH chain AS (
--         SELECT 
--             audit_id,
--             row_hash,
--             LAG(row_hash) OVER (ORDER BY audit_id) as expected_prev_hash,
--             prev_hash,
--             audit_id = 1 OR prev_hash = LAG(row_hash) OVER (ORDER BY audit_id) as is_valid
--         FROM Audit.audit_logs
--     )
--     SELECT audit_id::INT, is_valid, 
--            CASE WHEN NOT is_valid THEN audit_id::INT ELSE NULL END
--     FROM chain;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- Run periodically:
-- -- SELECT * FROM Audit.verify_audit_chain() WHERE NOT is_valid;

