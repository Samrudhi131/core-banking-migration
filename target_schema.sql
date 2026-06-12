-- ============================================================
-- Target Core Banking Schema (Modern / Normalized)
-- Used as TARGET in the migration exercise
-- ============================================================

CREATE DATABASE IF NOT EXISTS cbs_modern;
USE cbs_modern;

-- Customer (normalized: address separated)
CREATE TABLE customers (
    customer_id         BIGINT          NOT NULL AUTO_INCREMENT,
    legacy_cust_id      INT,                         -- traceability to source
    full_name           VARCHAR(200)    NOT NULL,
    date_of_birth       DATE,
    pan_number          VARCHAR(10),
    aadhar_number       VARCHAR(12),
    kyc_verified        BOOLEAN         DEFAULT FALSE,
    kyc_verified_date   DATE,
    status              ENUM('ACTIVE','INACTIVE','DECEASED','MERGED') DEFAULT 'ACTIVE',
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id),
    UNIQUE KEY uq_pan (pan_number),
    KEY idx_legacy (legacy_cust_id)
);

-- Customer Addresses (separated from customer)
CREATE TABLE customer_addresses (
    address_id          BIGINT          NOT NULL AUTO_INCREMENT,
    customer_id         BIGINT          NOT NULL,
    address_type        ENUM('PERMANENT','CORRESPONDENCE','OFFICE') DEFAULT 'PERMANENT',
    address_line1       VARCHAR(200),
    address_line2       VARCHAR(200),
    city                VARCHAR(100),
    state               VARCHAR(100),
    pincode             VARCHAR(10),
    country             VARCHAR(50)     DEFAULT 'India',
    is_primary          BOOLEAN         DEFAULT TRUE,
    PRIMARY KEY (address_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Customer Contacts
CREATE TABLE customer_contacts (
    contact_id          BIGINT          NOT NULL AUTO_INCREMENT,
    customer_id         BIGINT          NOT NULL,
    contact_type        ENUM('MOBILE','EMAIL','LANDLINE') NOT NULL,
    contact_value       VARCHAR(100)    NOT NULL,
    is_primary          BOOLEAN         DEFAULT TRUE,
    is_verified         BOOLEAN         DEFAULT FALSE,
    PRIMARY KEY (contact_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Branches
CREATE TABLE branches (
    branch_id           INT             NOT NULL AUTO_INCREMENT,
    legacy_branch_code  VARCHAR(10),
    branch_name         VARCHAR(200),
    ifsc_code           VARCHAR(11),
    city                VARCHAR(100),
    state               VARCHAR(100),
    region              VARCHAR(50),
    is_active           BOOLEAN         DEFAULT TRUE,
    PRIMARY KEY (branch_id),
    UNIQUE KEY uq_ifsc (ifsc_code),
    KEY idx_legacy_branch (legacy_branch_code)
);

-- Accounts
CREATE TABLE accounts (
    account_id          BIGINT          NOT NULL AUTO_INCREMENT,
    account_number      VARCHAR(20)     NOT NULL,
    legacy_account_no   VARCHAR(20),
    customer_id         BIGINT          NOT NULL,
    account_type        ENUM('SAVINGS','CURRENT','FIXED_DEPOSIT','RECURRING','LOAN') NOT NULL,
    account_status      ENUM('ACTIVE','DORMANT','CLOSED','FROZEN') DEFAULT 'ACTIVE',
    branch_id           INT,
    currency_code       CHAR(3)         DEFAULT 'INR',
    current_balance     DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    available_balance   DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    hold_amount         DECIMAL(18,2)   DEFAULT 0.00,
    interest_rate       DECIMAL(6,4),
    open_date           DATE            NOT NULL,
    close_date          DATE,
    last_transaction_at TIMESTAMP,
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (account_id),
    UNIQUE KEY uq_account_number (account_number),
    KEY idx_customer (customer_id),
    KEY idx_legacy_acct (legacy_account_no),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
);

-- Transactions
CREATE TABLE transactions (
    transaction_id          BIGINT          NOT NULL AUTO_INCREMENT,
    legacy_txn_id           BIGINT,
    account_id              BIGINT          NOT NULL,
    transaction_date        DATE            NOT NULL,
    value_date              DATE,
    transaction_type        ENUM('CREDIT','DEBIT') NOT NULL,
    transaction_mode        ENUM('CASH','NEFT','RTGS','IMPS','CHEQUE','UPI','INTERNAL') NOT NULL,
    amount                  DECIMAL(18,2)   NOT NULL,
    balance_after           DECIMAL(18,2),
    narration               VARCHAR(500),
    reference_number        VARCHAR(50),
    channel                 ENUM('BRANCH','ATM','INTERNET','MOBILE','API') DEFAULT 'BRANCH',
    transaction_status      ENUM('SUCCESS','FAILED','REVERSED','PENDING') DEFAULT 'SUCCESS',
    created_at              TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_id),
    KEY idx_account (account_id),
    KEY idx_txn_date (transaction_date),
    KEY idx_legacy_txn (legacy_txn_id),
    FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- Migration Audit Trail
CREATE TABLE migration_audit (
    audit_id            BIGINT          NOT NULL AUTO_INCREMENT,
    migration_run_id    VARCHAR(50),
    table_name          VARCHAR(100),
    source_count        BIGINT,
    target_count        BIGINT,
    checksum_source     DECIMAL(20,2),
    checksum_target     DECIMAL(20,2),
    status              ENUM('PASS','FAIL','WARNING') DEFAULT 'PASS',
    run_at              TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    notes               TEXT,
    PRIMARY KEY (audit_id)
);

SELECT 'Target schema created successfully' AS status;
