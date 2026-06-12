# Core Banking System Migration - Data Mapping & Validation Framework

## Business Context
A regional bank was migrating its core banking system (CBS) from a legacy Oracle-based platform to a modern centralized schema. The primary risk: data integrity loss during migration - mismatched account balances, truncated customer records, or broken transaction histories. This project delivers the migration mapping documentation, transformation scripts, and a post-migration validation framework that ensures zero data loss.

## Approach
- Reverse-engineered legacy CBS schema and mapped 12 core tables to the target schema
- Built Python + PL/SQL transformation scripts to handle data type conversions, null handling, and referential integrity
- Developed a validation layer performing row-count checks, checksum verification, and business-rule assertions
- Produced a migration runbook - the kind of artifact a consultant would hand off to the client's IT team

## Business Impact
- Validation framework detected 3 categories of data anomalies in test migration runs before go-live
- Row-count reconciliation accuracy: 100% across all migrated tables in UAT
- Runbook adopted as standard migration documentation template for future CBS migrations

## Tech Stack
`Oracle PL/SQL` · `Python` · `MySQL` · `Pandas` · `SQLAlchemy` · `openpyxl`

## Project Structure
```
core-banking-migration/
├── data/
│   ├── legacy_accounts_sample.csv     # Mock legacy CBS data
│   ├── legacy_customers_sample.csv
│   └── legacy_transactions_sample.csv
├── scripts/
│   ├── legacy_schema.sql              # Legacy CBS schema (Oracle)
│   ├── target_schema.sql              # Target modern schema
│   ├── transform_accounts.py          # Transformation: accounts table
│   ├── transform_customers.py         # Transformation: customers table
│   └── validation_framework.py        # Post-migration validation checks
├── mapping_docs/
│   ├── field_mapping_matrix.xlsx      # Source → Target field mapping
│   └── migration_runbook.md           # Step-by-step migration playbook
├── validation/
│   └── validation_report_sample.csv   # Sample validation output
└── README.md
```

## How to Run
```bash
# 1. Set up schemas
sqlplus user/pass@legacy @scripts/legacy_schema.sql
mysql -u root -p < scripts/target_schema.sql

# 2. Run transformations
python scripts/transform_accounts.py
python scripts/transform_customers.py

# 3. Validate migration
python scripts/validation_framework.py --env UAT

# 4. Review report
cat validation/validation_report_sample.csv
```

## Key Validation Checks
| Check | Description |
|---|---|
| Row count reconciliation | Source count = Target count per table |
| Checksum verification | SUM(balance) source = SUM(balance) target |
| Null integrity | No nulls in NOT NULL columns post-migration |
| Referential integrity | All foreign keys resolve in target |
| Business rules | Account balance ≥ 0, valid account types, etc. |
| Data type fidelity | No truncation in VARCHAR → VARCHAR(n) conversions |

## Consulting Relevance
This project simulates the core deliverable of a **Technology Strategy & Transformation** engagement: helping a financial institution safely migrate critical systems. The mapping document and runbook mirror real consulting artifacts (solution design, migration playbook) used in Big 4 FS technology projects.
