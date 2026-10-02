BEGIN;

CREATE OR REPLACE FUNCTION Audit.Guard_trigger()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only block direct INSERTs if the setting is not enabled
    IF current_setting('app.allow_direct_insert', true) IS NULL THEN
        RAISE EXCEPTION 'Direct INSERT is not allowed';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
    
END;
$$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;
;
-- 1
CREATE TRIGGER Guard_audit_transactions
BEFORE INSERT OR UPDATE OR DELETE ON Finance.transactions
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();
-- 2
CREATE TRIGGER Guard_audit_inventory
BEFORE INSERT OR UPDATE OR DELETE ON Finance.inventory_audits
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();
-- 3
CREATE TRIGGER Guard_audit_journals
BEFORE INSERT OR UPDATE OR DELETE ON Finance.journals
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();
-- 4
CREATE TRIGGER Guard_audit_ap
BEFORE INSERT OR UPDATE OR DELETE ON Finance.account_payables
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--payable_id);
-- 5
CREATE TRIGGER Guard_audit_ar
BEFORE INSERT OR UPDATE OR DELETE ON Finance.account_receivables
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--receivable_id);
-- 6
CREATE TRIGGER Guard_customer_changes 
BEFORE INSERT OR UPDATE OR DELETE ON Finance.customers 
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--customer_id);
-- 7 
CREATE TRIGGER Guard_supplier_changes 
BEFORE INSERT OR UPDATE OR DELETE ON Finance.vendors 
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--vendor_id);
-- 8
CREATE TRIGGER Guard_product_changes 
BEFORE INSERT OR UPDATE OR DELETE ON Finance.products 
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--product_id);
-- 9
CREATE TRIGGER Guard_inventory_transfers_changes 
BEFORE INSERT OR UPDATE OR DELETE ON Finance.inventory_transfers 
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--transfer_id);
-- 10
CREATE TRIGGER Guard_purchase_returns_changes 
BEFORE INSERT OR UPDATE OR DELETE ON Finance.purchase_returns 
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--return_id);
-- 11
CREATE TRIGGER Guard_warehouse_changes 
BEFORE INSERT OR UPDATE OR DELETE ON Finance.warehouses 
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--warehouse_id);
-- 12
CREATE TRIGGER Guard_sale_returns_changes 
BEFORE INSERT OR UPDATE OR DELETE ON Finance.sale_returns 
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--return_id);
-- 13
CREATE TRIGGER Guard_clients_changes 
BEFORE INSERT OR UPDATE OR DELETE ON Finance.clients
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--client_id);
-- 14
CREATE TRIGGER Guard_coatemplates_changes
BEFORE INSERT OR UPDATE OR DELETE ON Finance.coa_templates
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--template_id);
-- 15
CREATE TRIGGER Guard_account_roles_changes
BEFORE INSERT OR UPDATE OR DELETE ON Finance.account_roles
FOR  EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--role_id);
-- 16
CREATE TRIGGER Guard_account_properties_changes 
BEFORE INSERT OR UPDATE OR DELETE ON Finance.account_properties
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--property_id);
-- 17
CREATE TRIGGER Guard_account_receivables_ext_changes
BEFORE INSERT OR UPDATE OR DELETE ON Finance.ar_ext
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--ar_ext_id);
-- 18
CREATE TRIGGER Guard_account_payables_ext_changes
BEFORE INSERT OR UPDATE OR DELETE ON Finance.ap_ext
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--ap_ext_id);
-- 19
CREATE TRIGGER Guard_coa_templates_account_changes
BEFORE INSERT OR UPDATE OR DELETE ON Finance.coa_template_accounts
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--template_account_Id);
-- 20
CREATE TRIGGER Guard_charts_changes
BEFORE INSERT OR UPDATE OR DELETE ON Finance.charts
FOR EACH ROW EXECUTE FUNCTION Audit.Guard_trigger();--chart_id);

COMMIT;

SELECT '32 Guard Triggers Complete' AS STATUS;