"""
Core Banking Migration — Post-Migration Validation Framework
=============================================================
Runs a comprehensive suite of data quality checks after migration.
Outputs a validation report flagging any anomalies for remediation.
"""

import pandas as pd
import sqlalchemy as sa
from sqlalchemy import create_engine, text
from datetime import datetime
import logging
import os
import argparse
import uuid

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

LEGACY_DB_URL  = os.getenv("LEGACY_DB_URL",  "oracle+cx_oracle://user:pass@localhost/LEGACYCBS")
TARGET_DB_URL  = os.getenv("TARGET_DB_URL",  "mysql+mysqlconnector://root:password@localhost/cbs_modern")
REPORTS_DIR    = os.path.join(os.path.dirname(__file__), "..", "validation")

TABLE_MAP = {
    # legacy_table: (target_table, legacy_count_col, target_count_col, checksum_col)
    "CBS_CUSTOMER_MASTER": ("customers",    "CUST_ID",  "customer_id",  None),
    "CBS_ACCT_MASTER":     ("accounts",     "ACCT_NO",  "account_number", "CURR_BAL"),
    "CBS_TXN_HIST":        ("transactions", "TXN_ID",   "transaction_id", "TXN_AMT"),
    "CBS_BRANCH_MASTER":   ("branches",     "BRANCH_CD","branch_id",    None),
}


class ValidationResult:
    def __init__(self, check_name, table, status, detail="", expected=None, actual=None):
        self.check_name = check_name
        self.table      = table
        self.status     = status   # PASS / FAIL / WARNING
        self.detail     = detail
        self.expected   = expected
        self.actual     = actual

    def to_dict(self):
        return {
            "check_name": self.check_name,
            "table":      self.table,
            "status":     self.status,
            "expected":   self.expected,
            "actual":     self.actual,
            "detail":     self.detail,
        }


class MigrationValidator:

    def __init__(self, legacy_engine, target_engine, run_id: str):
        self.legacy  = legacy_engine
        self.target  = target_engine
        self.run_id  = run_id
        self.results = []

    def _pass(self, check, table, detail="", expected=None, actual=None):
        r = ValidationResult(check, table, "PASS", detail, expected, actual)
        self.results.append(r)
        logger.info(f"  ✓ PASS  [{table}] {check}")

    def _fail(self, check, table, detail="", expected=None, actual=None):
        r = ValidationResult(check, table, "FAIL", detail, expected, actual)
        self.results.append(r)
        logger.error(f"  ✗ FAIL  [{table}] {check} — {detail}")

    def _warn(self, check, table, detail="", expected=None, actual=None):
        r = ValidationResult(check, table, "WARNING", detail, expected, actual)
        self.results.append(r)
        logger.warning(f"  ⚠ WARN  [{table}] {check} — {detail}")

    # ── Check 1: Row Count Reconciliation ─────────────────────────────────────

    def check_row_counts(self):
        logger.info("\n[1] Row Count Reconciliation")
        for legacy_tbl, (target_tbl, _, _, _) in TABLE_MAP.items():
            try:
                with self.legacy.connect() as conn:
                    src_count = conn.execute(
                        text(f"SELECT COUNT(*) FROM {legacy_tbl}")
                    ).scalar()
                with self.target.connect() as conn:
                    tgt_count = conn.execute(
                        text(f"SELECT COUNT(*) FROM {target_tbl}")
                    ).scalar()

                if src_count == tgt_count:
                    self._pass("ROW_COUNT", legacy_tbl,
                               f"{src_count:,} rows match", src_count, tgt_count)
                elif abs(src_count - tgt_count) / max(src_count, 1) < 0.001:
                    self._warn("ROW_COUNT", legacy_tbl,
                               f"<0.1% variance: {src_count:,} vs {tgt_count:,}",
                               src_count, tgt_count)
                else:
                    self._fail("ROW_COUNT", legacy_tbl,
                               f"MISMATCH: legacy={src_count:,}, target={tgt_count:,}",
                               src_count, tgt_count)
            except Exception as e:
                self._fail("ROW_COUNT", legacy_tbl, str(e))

    # ── Check 2: Financial Checksum ───────────────────────────────────────────

    def check_financial_checksums(self):
        logger.info("\n[2] Financial Checksum Verification")

        checksums = [
            ("CBS_ACCT_MASTER",  "SUM(CURR_BAL)",
             "accounts",         "SUM(current_balance)"),
            ("CBS_TXN_HIST",     "SUM(TXN_AMT)",
             "transactions",     "SUM(amount)"),
        ]

        for legacy_tbl, src_expr, target_tbl, tgt_expr in checksums:
            try:
                with self.legacy.connect() as conn:
                    src_sum = conn.execute(
                        text(f"SELECT {src_expr} FROM {legacy_tbl}")
                    ).scalar() or 0

                with self.target.connect() as conn:
                    tgt_sum = conn.execute(
                        text(f"SELECT {tgt_expr} FROM {target_tbl}")
                    ).scalar() or 0

                variance = abs(float(src_sum) - float(tgt_sum))

                if variance < 0.01:
                    self._pass("FINANCIAL_CHECKSUM", legacy_tbl,
                               f"Sums match: {src_sum:,.2f}", src_sum, tgt_sum)
                else:
                    self._fail("FINANCIAL_CHECKSUM", legacy_tbl,
                               f"Variance: INR {variance:,.2f}", src_sum, tgt_sum)
            except Exception as e:
                self._fail("FINANCIAL_CHECKSUM", legacy_tbl, str(e))

    # ── Check 3: Null Integrity ───────────────────────────────────────────────

    def check_null_integrity(self):
        logger.info("\n[3] Null Integrity Check (NOT NULL columns)")

        null_checks = [
            ("customers",     "full_name"),
            ("customers",     "customer_id"),
            ("accounts",      "account_number"),
            ("accounts",      "customer_id"),
            ("accounts",      "current_balance"),
            ("transactions",  "amount"),
            ("transactions",  "transaction_date"),
            ("transactions",  "transaction_type"),
        ]

        with self.target.connect() as conn:
            for table, col in null_checks:
                try:
                    count = conn.execute(
                        text(f"SELECT COUNT(*) FROM {table} WHERE {col} IS NULL")
                    ).scalar()

                    if count == 0:
                        self._pass("NULL_INTEGRITY", table,
                                   f"{col}: no nulls", 0, 0)
                    else:
                        self._fail("NULL_INTEGRITY", table,
                                   f"{col}: {count:,} null values found", 0, count)
                except Exception as e:
                    self._fail("NULL_INTEGRITY", table, str(e))

    # ── Check 4: Referential Integrity ────────────────────────────────────────

    def check_referential_integrity(self):
        logger.info("\n[4] Referential Integrity Check")

        fk_checks = [
            ("accounts",     "customer_id",  "customers",  "customer_id"),
            ("transactions", "account_id",   "accounts",   "account_id"),
            ("accounts",     "branch_id",    "branches",   "branch_id"),
        ]

        with self.target.connect() as conn:
            for child_tbl, fk_col, parent_tbl, pk_col in fk_checks:
                try:
                    orphan_count = conn.execute(text(f"""
                        SELECT COUNT(*) FROM {child_tbl} c
                        LEFT JOIN {parent_tbl} p ON c.{fk_col} = p.{pk_col}
                        WHERE c.{fk_col} IS NOT NULL AND p.{pk_col} IS NULL
                    """)).scalar()

                    if orphan_count == 0:
                        self._pass("REFERENTIAL_INTEGRITY",
                                   f"{child_tbl}.{fk_col}",
                                   "No orphan records", 0, 0)
                    else:
                        self._fail("REFERENTIAL_INTEGRITY",
                                   f"{child_tbl}.{fk_col}",
                                   f"{orphan_count:,} orphan records found", 0, orphan_count)
                except Exception as e:
                    self._fail("REFERENTIAL_INTEGRITY", child_tbl, str(e))

    # ── Check 5: Business Rules ───────────────────────────────────────────────

    def check_business_rules(self):
        logger.info("\n[5] Business Rule Validation")

        with self.target.connect() as conn:
            # Rule: No negative balances in savings accounts
            try:
                count = conn.execute(text("""
                    SELECT COUNT(*) FROM accounts
                    WHERE account_type = 'SAVINGS' AND current_balance < 0
                """)).scalar()
                if count == 0:
                    self._pass("BIZ_RULE_NEG_BALANCE", "accounts",
                               "No negative savings balances")
                else:
                    self._fail("BIZ_RULE_NEG_BALANCE", "accounts",
                               f"{count:,} savings accounts with negative balance", 0, count)
            except Exception as e:
                self._fail("BIZ_RULE_NEG_BALANCE", "accounts", str(e))

            # Rule: Transaction amounts must be > 0
            try:
                count = conn.execute(text("""
                    SELECT COUNT(*) FROM transactions WHERE amount <= 0
                """)).scalar()
                if count == 0:
                    self._pass("BIZ_RULE_TXN_AMOUNT", "transactions",
                               "All transaction amounts > 0")
                else:
                    self._fail("BIZ_RULE_TXN_AMOUNT", "transactions",
                               f"{count:,} transactions with amount <= 0", 0, count)
            except Exception as e:
                self._fail("BIZ_RULE_TXN_AMOUNT", "transactions", str(e))

            # Rule: Closed accounts should have zero balance
            try:
                count = conn.execute(text("""
                    SELECT COUNT(*) FROM accounts
                    WHERE account_status = 'CLOSED' AND current_balance != 0
                """)).scalar()
                if count == 0:
                    self._pass("BIZ_RULE_CLOSED_BALANCE", "accounts",
                               "All closed accounts have zero balance")
                else:
                    self._warn("BIZ_RULE_CLOSED_BALANCE", "accounts",
                               f"{count:,} closed accounts with non-zero balance", 0, count)
            except Exception as e:
                self._fail("BIZ_RULE_CLOSED_BALANCE", "accounts", str(e))

    # ── Report ─────────────────────────────────────────────────────────────────

    def generate_report(self) -> str:
        os.makedirs(REPORTS_DIR, exist_ok=True)
        df = pd.DataFrame([r.to_dict() for r in self.results])

        filename = f"validation_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        filepath = os.path.join(REPORTS_DIR, filename)
        df.to_csv(filepath, index=False)

        # Summary
        summary = df["status"].value_counts()
        logger.info("\n" + "=" * 50)
        logger.info("VALIDATION SUMMARY")
        logger.info("=" * 50)
        for status, count in summary.items():
            logger.info(f"  {status}: {count}")
        logger.info(f"\nFull report: {filepath}")

        return filepath

    def run_all(self):
        logger.info(f"\nMigration Validation Run: {self.run_id}")
        logger.info("=" * 50)
        self.check_row_counts()
        self.check_financial_checksums()
        self.check_null_integrity()
        self.check_referential_integrity()
        self.check_business_rules()
        return self.generate_report()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", default="UAT", choices=["UAT", "PROD"])
    args = parser.parse_args()

    run_id = f"MIG-{datetime.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"

    legacy_engine = create_engine(LEGACY_DB_URL)
    target_engine = create_engine(TARGET_DB_URL)

    validator = MigrationValidator(legacy_engine, target_engine, run_id)
    validator.run_all()
