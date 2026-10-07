-- ============================================
-- 03_SECURITY_ACCESS_CONTROL_FRAMEWORK.SQL
-- Purpose: Security, authentication, and access control
-- ============================================

BEGIN;

--DROP SCHEMA IF EXISTS admin_meta CASCADE;
--CREATE SCHEMA admin_meta;


-- admin_meta role (full access)
--DROP ROLE IF EXISTS role_db_admin;
-- ============================================
-- Admin Role
-- ============================================
CREATE ROLE role_db_admin;
-- Finance
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA Finance TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Finance TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA Finance TO role_db_admin;
GRANT ALL PRIVILEGES ON SCHEMA Finance TO role_db_admin;

-- Audit (restricted: no DELETE, TRUNCATE, DROP)
GRANT SELECT, UPDATE, INSERT ON ALL TABLES IN SCHEMA Audit TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Audit TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA Audit TO role_db_admin;
GRANT ALL PRIVILEGES ON SCHEMA Audit TO role_db_admin;

-- Compliance (restricted: no DELETE, TRUNCATE, DROP)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA Compliance TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Compliance TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA Compliance TO role_db_admin;
GRANT ALL PRIVILEGES ON SCHEMA Compliance TO role_db_admin;

-- Staging, Governance, Management, admin_meta — ALL PRIVILEGES as before
-- Staging
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA Staging TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Staging TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA Staging TO role_db_admin;
GRANT ALL PRIVILEGES ON SCHEMA Staging TO role_db_admin;
-- Governance
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA governance_v2 TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA governance_v2 TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA governance_v2 TO role_db_admin;
GRANT ALL PRIVILEGES ON SCHEMA governance_v2 TO role_db_admin;
-- Management
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA Management TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Management TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA Management TO role_db_admin;
GRANT ALL PRIVILEGES ON SCHEMA Management TO role_db_admin;
-- admin_meta
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA admin_meta TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA admin_meta TO role_db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA admin_meta TO role_db_admin;
GRANT ALL PRIVILEGES ON SCHEMA admin_meta TO role_db_admin;


ALTER DEFAULT PRIVILEGES IN SCHEMA admin_meta GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA admin_meta GRANT ALL ON SEQUENCES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA admin_meta GRANT ALL ON FUNCTIONS TO role_db_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA Management GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Management GRANT ALL ON SEQUENCES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Management GRANT ALL ON FUNCTIONS TO role_db_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA governance_v2 GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA governance_v2 GRANT ALL ON SEQUENCES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA governance_v2 GRANT ALL ON FUNCTIONS TO role_db_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT ALL ON SEQUENCES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT ALL ON FUNCTIONS TO role_db_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA Compliance GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Compliance GRANT ALL ON SEQUENCES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Compliance GRANT ALL ON FUNCTIONS TO role_db_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA Audit GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Audit GRANT ALL ON SEQUENCES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Audit GRANT ALL ON FUNCTIONS TO role_db_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA Staging GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Staging GRANT ALL ON SEQUENCES TO role_db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Staging GRANT ALL ON FUNCTIONS TO role_db_admin;

-- Default privileges — AUDIT and COMPLIANCE now match the restricted grants
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Audit GRANT SELECT, UPDATE, INSERT ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Compliance GRANT SELECT, INSERT, UPDATE ON TABLES TO role_db_admin;

-- Other schemas — ALL as before
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA admin_meta GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Management GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA governance_v2 GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Finance GRANT ALL ON TABLES TO role_db_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Staging GRANT ALL ON TABLES TO role_db_admin;


-- ============================================
-- Read-only role
-- ============================================

--DROP ROLE IF EXISTS db_readonly;
CREATE ROLE db_readonly;
GRANT USAGE ON SCHEMA Finance TO db_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA Finance TO db_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT SELECT ON TABLES TO db_readonly;

-- Analyst role (read + reporting)
--DROP ROLE IF EXISTS db_analyst;
CREATE ROLE db_analyst;
GRANT USAGE ON SCHEMA Finance TO db_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA Finance TO db_analyst;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Finance TO db_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT SELECT ON TABLES TO db_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT EXECUTE ON FUNCTIONS TO db_analyst;

-- Application role (data import/export)
--DROP ROLE IF EXISTS db_app;
CREATE ROLE db_app;
GRANT USAGE ON SCHEMA Finance TO db_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA Finance TO db_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Finance TO db_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Finance TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT ALL ON SEQUENCES TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT SELECT, INSERT,UPDATE ON TABLES TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT EXECUTE ON FUNCTIONS TO db_app;

GRANT USAGE ON SCHEMA Audit TO db_app;
GRANT INSERT,UPDATE,SELECT ON ALL TABLES IN SCHEMA Audit TO db_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Audit TO db_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Audit TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Audit GRANT ALL ON SEQUENCES TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Audit GRANT INSERT,UPDATE,SELECT ON TABLES TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Audit GRANT EXECUTE ON FUNCTIONS TO db_app;

GRANT USAGE ON SCHEMA Compliance TO db_app;
GRANT INSERT,UPDATE,SELECT ON ALL TABLES IN SCHEMA Compliance TO db_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Compliance TO db_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Compliance TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Compliance GRANT ALL ON SEQUENCES TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Compliance GRANT INSERT,UPDATE,SELECT ON TABLES TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Compliance GRANT EXECUTE ON FUNCTIONS TO db_app;

GRANT USAGE ON SCHEMA Staging TO db_app;
GRANT INSERT,UPDATE, SELECT ON ALL TABLES IN SCHEMA Staging TO db_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Staging TO db_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Staging TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Staging GRANT ALL ON SEQUENCES TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Staging GRANT INSERT,UPDATE,SELECT ON TABLES TO db_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA Staging GRANT EXECUTE ON FUNCTIONS TO db_app;
-- ============================================
-- Application Role — Audit/Compliance: SELECT, INSERT only
-- ============================================
-- GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA Audit TO db_app;
-- GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA Compliance TO db_app;
-- (remove UPDATE from these)

-- ============================================
-- Auditor role (audit logging access)
-- ============================================
--DROP ROLE IF EXISTS db_auditor;
CREATE ROLE db_auditor;
GRANT USAGE ON SCHEMA Finance TO db_auditor;
GRANT USAGE ON SCHEMA admin_meta TO db_auditor;
GRANT USAGE ON SCHEMA Audit TO db_auditor;
GRANT USAGE ON SCHEMA Compliance TO db_auditor;
GRANT USAGE ON SCHEMA governance_v2 TO db_auditor;
GRANT USAGE ON SCHEMA Management TO db_auditor;
GRANT USAGE ON SCHEMA Staging TO db_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA Finance TO db_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA admin_meta TO db_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA Audit TO db_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA Compliance TO db_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA governance_v2 TO db_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA Management TO db_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA Staging TO db_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT SELECT ON TABLES TO db_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA Audit GRANT SELECT ON TABLES TO db_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA Compliance GRANT SELECT ON TABLES TO db_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA admin_meta GRANT SELECT ON TABLES TO db_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA governance_v2 GRANT SELECT ON TABLES TO db_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA Staging GRANT SELECT ON TABLES TO db_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA Management GRANT SELECT ON TABLES TO db_auditor;

-- ============================================
-- 4. CREATE DATABASE USERS
-- ============================================

-- Example users (change passwords in production)
DROP USER IF EXISTS admin_user;
CREATE USER admin_user WITH PASSWORD 'change_me_in_production' IN ROLE role_db_admin;

DROP USER IF EXISTS app_user;
CREATE USER app_user WITH PASSWORD 'change_me_in_production' IN ROLE db_app;

DROP USER IF EXISTS analyst_user;
CREATE USER analyst_user WITH PASSWORD 'change_me_in_production' IN ROLE db_analyst;

DROP USER IF EXISTS readonly_user;
CREATE USER readonly_user WITH PASSWORD 'change_me_in_production' IN ROLE db_readonly;

DROP USER IF EXISTS auditor_user;
CREATE USER auditor_user WITH PASSWORD 'change_me_in_production' IN ROLE db_auditor;

-- ============================================
-- 5. PASSWORD POLICY FUNCTIONS
-- ============================================

-- ============================================
-- 1. USER & ROLE MANAGEMENT TABLES
-- ============================================

DROP TABLE IF EXISTS admin_meta.user_access_log CASCADE;
CREATE TABLE admin_meta.user_access_log (
    access_id BIGSERIAL PRIMARY KEY,
    user_name VARCHAR(100) NOT NULL,
    login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    logout_time TIMESTAMP,
    ip_address INET,
    session_duration INTERVAL,
    access_type VARCHAR(50),  -- 'LOGIN', 'QUERY', 'MODIFICATION'
    status VARCHAR(20) CHECK (status IN ('SUCCESS', 'FAILED')),
    failure_reason TEXT,
    database_accessed VARCHAR(100)
);

CREATE INDEX idx_user_access_time ON admin_meta.user_access_log(login_time DESC);
CREATE INDEX idx_user_access_user ON admin_meta.user_access_log(user_name);
CREATE INDEX idx_user_access_status ON admin_meta.user_access_log(status);

-- ============================================
-- 2. SECURITY AUDIT TABLES
-- ============================================

DROP TABLE IF EXISTS admin_meta.security_events CASCADE;
CREATE TABLE admin_meta.security_events (
    event_id BIGSERIAL PRIMARY KEY,
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    event_type VARCHAR(100) NOT NULL,  -- 'PERMISSION_CHANGE', 'FAILED_LOGIN', 'SENSITIVE_DATA_ACCESS'
    severity VARCHAR(20) CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    user_name VARCHAR(100),
    affected_object VARCHAR(255),
    action_description TEXT,
    response_action TEXT
);

CREATE INDEX idx_security_events_time ON admin_meta.security_events(event_time DESC);
CREATE INDEX idx_security_events_severity ON admin_meta.security_events(severity);
CREATE INDEX idx_security_events_type ON admin_meta.security_events(event_type);

-- ============================================
-- 3. CREATE DATABASE ROLES
-- ============================================


DROP FUNCTION IF EXISTS admin_meta.validate_password_strength(VARCHAR) CASCADE;
CREATE FUNCTION admin_meta.validate_password_strength(p_password VARCHAR)
RETURNS TABLE(is_valid BOOLEAN, errors TEXT) AS $$
DECLARE
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Minimum length
    IF LENGTH(p_password) < 12 THEN
        v_errors := array_append(v_errors, 'Password must be at least 12 characters');
    END IF;
    
    -- Must contain uppercase
    IF p_password !~ '[A-Z]' THEN
        v_errors := array_append(v_errors, 'Password must contain uppercase letter');
    END IF;
    
    -- Must contain lowercase
    IF p_password !~ '[a-z]' THEN
        v_errors := array_append(v_errors, 'Password must contain lowercase letter');
    END IF;
    
    -- Must contain number
    IF p_password !~ '[0-9]' THEN
        v_errors := array_append(v_errors, 'Password must contain number');
    END IF;
    
    -- Must contain special character
    IF p_password !~ '[!@#$%^&*()_+\-=\[\]{};:,.<>?]' THEN
        v_errors := array_append(v_errors, 'Password must contain special character');
    END IF;
    
    RETURN QUERY SELECT 
        array_length(v_errors, 1) IS NULL,
        array_to_string(v_errors, '; ');
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. SECURITY MONITORING FUNCTIONS
-- ============================================

-- Log user access
DROP FUNCTION IF EXISTS admin_meta.log_user_access(VARCHAR, VARCHAR, INET, VARCHAR) CASCADE;
CREATE FUNCTION admin_meta.log_user_access(
    p_user_name VARCHAR,
    p_status VARCHAR,
    p_ip_address INET DEFAULT NULL,
    p_failure_reason VARCHAR DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_access_id BIGINT;
BEGIN
    INSERT INTO admin_meta.user_access_log (
        user_name, status, ip_address, failure_reason, access_type, database_accessed
    )
    VALUES (p_user_name, p_status, p_ip_address, p_failure_reason, 'LOGIN', current_database())
    RETURNING access_id INTO v_access_id;
    
    -- Log security event if failed
    IF p_status = 'FAILED' THEN
        PERFORM admin_meta.log_security_event(
            'FAILED_LOGIN', 'CRITICAL', p_user_name, 
            'Failed login attempt from ' || COALESCE(p_ip_address::TEXT, 'unknown'),
            p_failure_reason
        );
    END IF;
    
    RETURN v_access_id;
END;
$$ LANGUAGE plpgsql;

-- Log security event
DROP FUNCTION IF EXISTS admin_meta.log_security_event(VARCHAR, VARCHAR, VARCHAR, TEXT, TEXT) CASCADE;
CREATE FUNCTION admin_meta.log_security_event(
    p_event_type VARCHAR,
    p_severity VARCHAR,
    p_user_name VARCHAR,
    p_description TEXT,
    p_response_action TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_id BIGINT;
BEGIN
    INSERT INTO admin_meta.security_events (
        event_type, severity, user_name, action_description, response_action
    )
    VALUES (p_event_type, p_severity, p_user_name, p_description, p_response_action)
    RETURNING event_id INTO v_event_id;
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Get security violations
DROP FUNCTION IF EXISTS admin_meta.get_security_violations(INT) CASCADE;
CREATE FUNCTION admin_meta.get_security_violations(p_hours INT DEFAULT 24)
RETURNS TABLE(
    event_id BIGINT,
    event_time TIMESTAMP,
    event_type VARCHAR,
    severity VARCHAR,
    user_name VARCHAR,
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        se.event_id,
        se.event_time,
        se.event_type,
        se.severity,
        se.user_name,
        se.action_description
    FROM admin_meta.security_events se
    WHERE se.event_time > CURRENT_TIMESTAMP - (p_hours || ' hours')::INTERVAL
        AND se.severity IN ('WARNING', 'CRITICAL')
    ORDER BY se.event_time DESC;
END;
$$ LANGUAGE plpgsql;

-- Get user access history
DROP FUNCTION IF EXISTS admin_meta.get_user_access_history(VARCHAR, INT) CASCADE;
CREATE FUNCTION admin_meta.get_user_access_history(
    p_user_name VARCHAR,
    p_days INT DEFAULT 7
)
RETURNS TABLE(
    login_time TIMESTAMP,
    logout_time TIMESTAMP,
    ip_address INET,
    session_duration INTERVAL,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ual.login_time,
        ual.logout_time,
        ual.ip_address,
        ual.session_duration,
        ual.status
    FROM admin_meta.user_access_log ual
    WHERE ual.user_name = p_user_name
        AND ual.login_time > CURRENT_TIMESTAMP - (p_days || ' days')::INTERVAL
    ORDER BY ual.login_time DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verification
SELECT 'Security & Access Control Framework Successfully Installed' AS status;