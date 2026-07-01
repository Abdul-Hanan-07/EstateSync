-- Run this once against an existing EstateSync database to remove the audit
-- triggers that duplicated app.py's log_audit() calls (see database_script.sql
-- PART 3 for context). Safe to run even if a trigger was already removed.

DROP TRIGGER IF EXISTS trg_booking_insert;
DROP TRIGGER IF EXISTS trg_payment_update;
DROP TRIGGER IF EXISTS trg_plot_update;
DROP TRIGGER IF EXISTS trg_service_bill_update;
