CREATE OR REPLACE FUNCTION alter_tables_space_weekly_basis(
    schemaselect text,
    tableselected text
)
RETURNS void AS $$
DECLARE
    -- FIX: Use date_trunc('week') to get Monday of current week, then go back 1 week
    -- This matches the naming convention of the CREATE function
    current_week_monday date := date_trunc('week', current_date);
    target_week_monday date := current_week_monday - interval '7 days';
    week_number int := extract(week from target_week_monday)::int;
    part_name text;
BEGIN
    IF schemaselect NOT IN ('Finance','Audit','Staging','Compliance') THEN
        RAISE EXCEPTION 'Invalid schema %', schemaselect;
    END IF;

    IF tableselected NOT IN ('journals', 'ar_ext', 'ap_ext', 'inventory_audits') THEN
        RAISE EXCEPTION 'Invalid table %', tableselected;
    END IF;

    -- FIX: Use the Monday of the previous week for the name
    part_name := tableselected || '_' || to_char(target_week_monday,'YYYY_MM') || '_wk' || week_number;

    -- Check if partition exists before moving
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c 
        JOIN pg_namespace n ON n.oid = c.relnamespace 
        WHERE c.relname = part_name AND n.nspname = schemaselect
    ) THEN
        RAISE NOTICE 'Partition % does not exist. Skipping.', part_name;
        RETURN;
    END IF;

    EXECUTE format(
        'ALTER TABLE %I.%I SET TABLESPACE coldspace;',
        schemaselect,
        part_name
    );
    
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Finance partition weekly move : % : %', SQLSTATE, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;