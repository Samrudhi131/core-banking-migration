# CBS Migration Runbook
**Document Type:** Technical Migration Playbook  
**Version:** 1.0  
**Status:** Approved for UAT

---

## 1. Executive Summary

This runbook documents the end-to-end process for migrating customer, account, and transaction data from the legacy Core Banking System (CBS-Legacy) to the modernized target platform (CBS-Modern). It is intended for use by the migration team during UAT and production go-live.

**Scope:** 4 tables — Customer Master, Account Master, Transaction History, Branch Master  
**Estimated Record Volume:** ~2.5M transactions, ~180K accounts, ~95K customers  
**Target Go-Live Window:** Weekend cutover (Sat 10 PM → Sun 6 AM)

---

## 2. Pre-Migration Checklist

| # | Task | Owner | Status |
|---|------|-------|--------|
| 1 | Legacy system read-only mode enabled | DBA | ☐ |
| 2 | Full backup of legacy DB taken & verified | DBA | ☐ |
| 3 | Target DB schemas deployed and verified | Migration Lead | ☐ |
| 4 | Network connectivity legacy → target confirmed | Infra | ☐ |
| 5 | Migration scripts tested in staging | Dev | ☐ |
| 6 | Validation framework tested in staging | Dev | ☐ |
| 7 | Rollback plan reviewed and signed off | Project Manager | ☐ |
| 8 | Business stakeholders on standby | Business | ☐ |

---

## 3. Migration Sequence

### Phase 1: Reference Data (T-4 hours)
```bash
# 1. Migrate branch master (no dependencies)
python scripts/transform_branches.py --env PROD

# 2. Validate branches immediately
python scripts/validation_framework.py --env PROD --tables branches
```
**Expected duration:** 15 minutes  
**Go/No-Go check:** Row count + all branch IFSC codes present

---

### Phase 2: Customer Master (T-3 hours)
```bash
python scripts/transform_customers.py --env PROD --batch-size 10000
```
**Expected duration:** 45 minutes  
**Go/No-Go check:** Row count reconciliation, PAN deduplication report clean

---

### Phase 3: Account Master (T-2 hours)
```bash
python scripts/transform_accounts.py --env PROD --batch-size 5000
```
**Expected duration:** 30 minutes  
**Go/No-Go check:** Row count + SUM(CURR_BAL) checksum

---

### Phase 4: Transaction History (T-1 hour to T+0)
```bash
# Run in parallel batches by year
python scripts/transform_transactions.py --env PROD --year 2018 &
python scripts/transform_transactions.py --env PROD --year 2019 &
python scripts/transform_transactions.py --env PROD --year 2020 &
python scripts/transform_transactions.py --env PROD --year 2021 &
python scripts/transform_transactions.py --env PROD --year 2022 &
python scripts/transform_transactions.py --env PROD --year 2023 &
wait
python scripts/transform_transactions.py --env PROD --year 2024
```
**Expected duration:** 3.5 hours  
**Go/No-Go check:** Full SUM(TXN_AMT) checksum — must match to the penny

---

### Phase 5: Full Validation Suite (T+30 min)
```bash
python scripts/validation_framework.py --env PROD
```
All checks must return PASS or WARNING (no FAIL).

---

## 4. Field Mapping Summary

| Legacy Field | Legacy Type | Target Field | Target Type | Transform |
|---|---|---|---|---|
| CBS_CUSTOMER_MASTER.CUST_ID | NUMBER(10) | customers.legacy_cust_id | BIGINT | Direct |
| CUST_NAME | VARCHAR2(100) | full_name | VARCHAR(200) | TRIM + UPPER |
| CUST_DOB | DATE | date_of_birth | DATE | Direct |
| CUST_KYC_STAT | CHAR(1) Y/N | kyc_verified | BOOLEAN | 'Y'→TRUE |
| CUST_STAT | CHAR(1) A/I/D | status | ENUM | 'A'→ACTIVE, 'I'→INACTIVE |
| CBS_ACCT_MASTER.ACCT_TYPE | VARCHAR2(5) | account_type | ENUM | SB→SAVINGS, CA→CURRENT |
| ACCT_STAT | CHAR(1) A/D/C | account_status | ENUM | A→ACTIVE, D→DORMANT |
| CURR_BAL | NUMBER(15,2) | current_balance | DECIMAL(18,2) | Direct (precision increase) |
| CBS_TXN_HIST.TXN_TYPE | VARCHAR2(5) CR/DR | transaction_type | ENUM | CR→CREDIT, DR→DEBIT |
| TXN_MODE | VARCHAR2(10) | transaction_mode | ENUM | CHQ→CHEQUE, others direct |

---

## 5. Rollback Procedure

If any Phase 4 or Phase 5 check returns FAIL:

```bash
# 1. Immediately stop all migration scripts
kill $(pgrep -f transform_)

# 2. Notify stakeholders — escalation within 15 min
# Contact: Migration Lead, DBA Lead, Project Manager

# 3. Truncate target tables in reverse dependency order
mysql -u root -p cbs_modern -e "
  SET FOREIGN_KEY_CHECKS=0;
  TRUNCATE transactions;
  TRUNCATE accounts;
  TRUNCATE customer_addresses;
  TRUNCATE customer_contacts;
  TRUNCATE customers;
  TRUNCATE branches;
  SET FOREIGN_KEY_CHECKS=1;
"

# 4. Restore legacy system to read-write mode
# (DBA to execute Oracle DB parameter change)

# 5. Document incident and reschedule
```

---

## 6. Post Go-Live Verification (Business Day +1)

- [ ] Sample 50 random accounts: verify balance matches legacy print
- [ ] Confirm last 30 days of transactions visible in new system
- [ ] Customer login tested on new platform for 10 test accounts
- [ ] Regulatory reporting (RBI) confirmed functional
- [ ] Audit log from migration run archived to project documentation
