-- ============================================================
-- Legacy Core Banking System Schema (Oracle)
-- Simulates a typical 1990s-era CBS database structure
-- Used as SOURCE in the migration exercise
-- ============================================================

-- Customer Master (legacy flat structure, no normalization)
CREATE TABLE CBS_CUSTOMER_MASTER (
    CUST_ID         NUMBER(10)      NOT NULL,
    CUST_NAME       VARCHAR2(100)   NOT NULL,
    CUST_DOB        DATE,
    CUST_ADDR1      VARCHAR2(100),
    CUST_ADDR2      VARCHAR2(100),
    CUST_CITY       VARCHAR2(50),
    CUST_STATE      VARCHAR2(50),
    CUST_PIN        VARCHAR2(10),
    CUST_PHONE      VARCHAR2(20),
    CUST_EMAIL      VARCHAR2(100),
    CUST_PAN        VARCHAR2(10),
    CUST_AADHAR     VARCHAR2(12),
    CUST_KYC_STAT   CHAR(1)         DEFAULT 'N',  -- Y/N
    CUST_OPEN_DT    DATE            DEFAULT SYSDATE,
    CUST_STAT       CHAR(1)         DEFAULT 'A',  -- A=Active, I=Inactive, D=Deleted
    MAKER_ID        VARCHAR2(10),
    MAKER_DT        DATE,
    CHECKER_ID      VARCHAR2(10),
    CHECKER_DT      DATE,
    CONSTRAINT PK_CBS_CUST PRIMARY KEY (CUST_ID)
);

-- Account Master
CREATE TABLE CBS_ACCT_MASTER (
    ACCT_NO         VARCHAR2(20)    NOT NULL,
    CUST_ID         NUMBER(10)      NOT NULL,
    ACCT_TYPE       VARCHAR2(5),    -- SB=Savings, CA=Current, FD=Fixed Deposit, RD=Recurring
    ACCT_STAT       CHAR(1)         DEFAULT 'A',  -- A=Active, D=Dormant, C=Closed
    OPEN_DT         DATE,
    CLOSE_DT        DATE,
    CURR_BAL        NUMBER(15,2)    DEFAULT 0,
    AVAIL_BAL       NUMBER(15,2)    DEFAULT 0,
    HOLD_AMT        NUMBER(15,2)    DEFAULT 0,
    INT_RATE        NUMBER(5,2),
    BRANCH_CD       VARCHAR2(10),
    CURRENCY        VARCHAR2(3)     DEFAULT 'INR',
    NOMINEE_NM      VARCHAR2(100),
    JTHOLDER1_ID    NUMBER(10),
    JTHOLDER2_ID    NUMBER(10),
    LAST_TXN_DT     DATE,
    MAKER_ID        VARCHAR2(10),
    MAKER_DT        DATE,
    CONSTRAINT PK_CBS_ACCT PRIMARY KEY (ACCT_NO),
    CONSTRAINT FK_CBS_ACCT_CUST FOREIGN KEY (CUST_ID) REFERENCES CBS_CUSTOMER_MASTER(CUST_ID)
);

-- Transaction History (rolling 7-year archive)
CREATE TABLE CBS_TXN_HIST (
    TXN_ID          NUMBER(15)      NOT NULL,
    ACCT_NO         VARCHAR2(20)    NOT NULL,
    TXN_DT          DATE            NOT NULL,
    VALUE_DT        DATE,
    TXN_TYPE        VARCHAR2(5),    -- CR=Credit, DR=Debit
    TXN_MODE        VARCHAR2(10),   -- CASH, NEFT, RTGS, IMPS, CHQ, UPI
    TXN_AMT         NUMBER(15,2)    NOT NULL,
    BAL_AFTER       NUMBER(15,2),
    NARRATION       VARCHAR2(200),
    REF_NO          VARCHAR2(30),
    CHANNEL         VARCHAR2(10),   -- BRANCH, ATM, NET, MOB
    MAKER_ID        VARCHAR2(10),
    TXN_STAT        CHAR(1)         DEFAULT 'S',  -- S=Success, F=Failed, R=Reversed
    CONSTRAINT PK_CBS_TXN PRIMARY KEY (TXN_ID),
    CONSTRAINT FK_CBS_TXN_ACCT FOREIGN KEY (ACCT_NO) REFERENCES CBS_ACCT_MASTER(ACCT_NO)
);

-- Branch Master
CREATE TABLE CBS_BRANCH_MASTER (
    BRANCH_CD       VARCHAR2(10)    NOT NULL,
    BRANCH_NM       VARCHAR2(100),
    IFSC_CD         VARCHAR2(11),
    BRANCH_ADDR     VARCHAR2(200),
    CITY            VARCHAR2(50),
    STATE           VARCHAR2(50),
    REGION          VARCHAR2(20),
    MANAGER_NM      VARCHAR2(100),
    CONSTRAINT PK_CBS_BRANCH PRIMARY KEY (BRANCH_CD)
);

-- Indexes
CREATE INDEX IDX_ACCT_CUST ON CBS_ACCT_MASTER(CUST_ID);
CREATE INDEX IDX_TXN_ACCT ON CBS_TXN_HIST(ACCT_NO);
CREATE INDEX IDX_TXN_DT ON CBS_TXN_HIST(TXN_DT);
