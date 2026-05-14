/*=============================================================================
  COMPLIANCE AGENT WORKSHOP - STEP 3: COMPLIANCE TABLES & SEED DATA
  ===========================================================================
  Creates compliance-specific tables in GENERIC_DB.COMPLIANCE and seeds them
  with realistic data referencing parties PTY-000001 through PTY-000050.

  Tables created:
    - SCREENING_RESULTS   (watchlist/sanctions screening outcomes)
    - EDD_REVIEWS         (Enhanced Due Diligence review records)
    - PDD_SCHEDULE        (Periodic Due Diligence schedule)
    - RISK_RATINGS        (current risk rating per party)
    - REVIEW_QUEUE        (items awaiting analyst action)
    - AUDIT_LOG           (all compliance actions taken)

  Prerequisites: Run 01_setup.sql, 02_seed_data.sql
  Run as: CPR_WORKSHOP_ROLE
  ===========================================================================*/

-- ============================================================================
-- 3.0 ROLE & WAREHOUSE
-- ============================================================================

USE ROLE CPR_WORKSHOP_ROLE;
USE WAREHOUSE CPR_WORKSHOP_WH;
USE SCHEMA GENERIC_DB.COMPLIANCE;

-- ============================================================================
-- 3.1 SCREENING_RESULTS — Watchlist/sanctions screening outcomes
-- ============================================================================

CREATE OR REPLACE TABLE GENERIC_DB.COMPLIANCE.SCREENING_RESULTS (
    SCREENING_ID           VARCHAR(20)     NOT NULL,
    PARTY_KEY              VARCHAR(15)     NOT NULL,
    SCREENED_NAME          VARCHAR(200),
    SCREENING_TYPE         VARCHAR(30)     NOT NULL,
    MATCH_TYPE             VARCHAR(20)     NOT NULL,
    MATCHED_LIST           VARCHAR(30),
    MATCH_SCORE            NUMBER(5,2),
    RISK_CATEGORY          VARCHAR(30),
    STATUS                 VARCHAR(20)     NOT NULL DEFAULT 'COMPLETED',
    SCREENED_BY            VARCHAR(50),
    SCREENING_DATE         TIMESTAMP_NTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CLEARED_BY             VARCHAR(50),
    CLEARED_AT             TIMESTAMP_NTZ,
    NOTES                  VARCHAR(500),
    PRIMARY KEY (SCREENING_ID)
);

-- ============================================================================
-- 3.2 EDD_REVIEWS — Enhanced Due Diligence review records
-- ============================================================================

CREATE OR REPLACE TABLE GENERIC_DB.COMPLIANCE.EDD_REVIEWS (
    REVIEW_ID              VARCHAR(20)     NOT NULL,
    PARTY_KEY              VARCHAR(15)     NOT NULL,
    REVIEW_TYPE            VARCHAR(40)     NOT NULL DEFAULT 'ENHANCED_DUE_DILIGENCE',
    TRIGGER_REASON         VARCHAR(50)     NOT NULL,
    STATUS                 VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    RISK_SCORE             NUMBER(3,0),
    ASSIGNED_TO            VARCHAR(50),
    INITIATED_AT           TIMESTAMP_NTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    COMPLETED_AT           TIMESTAMP_NTZ,
    DUE_DATE               DATE,
    FINDINGS               VARCHAR(2000),
    RECOMMENDATION         VARCHAR(20),
    APPROVED_BY            VARCHAR(50),
    APPROVED_AT            TIMESTAMP_NTZ,
    PRIMARY KEY (REVIEW_ID)
);

-- ============================================================================
-- 3.3 PDD_SCHEDULE — Periodic Due Diligence schedule
-- ============================================================================

CREATE OR REPLACE TABLE GENERIC_DB.COMPLIANCE.PDD_SCHEDULE (
    PDD_ID                 VARCHAR(20)     NOT NULL,
    PARTY_KEY              VARCHAR(15)     NOT NULL,
    REVIEW_CYCLE           VARCHAR(20)     NOT NULL,
    LAST_REVIEW_DATE       DATE,
    NEXT_REVIEW_DATE       DATE            NOT NULL,
    STATUS                 VARCHAR(20)     NOT NULL DEFAULT 'ON_TRACK',
    RISK_TIER              VARCHAR(10)     NOT NULL DEFAULT 'LOW',
    ASSIGNED_TO            VARCHAR(50),
    PRIMARY KEY (PDD_ID)
);

-- ============================================================================
-- 3.4 RISK_RATINGS — Current risk rating per party
-- ============================================================================

CREATE OR REPLACE TABLE GENERIC_DB.COMPLIANCE.RISK_RATINGS (
    RATING_ID              VARCHAR(20)     NOT NULL,
    PARTY_KEY              VARCHAR(15)     NOT NULL UNIQUE,
    CURRENT_RATING         VARCHAR(10)     NOT NULL,
    PREVIOUS_RATING        VARCHAR(10),
    RATING_DATE            DATE            NOT NULL DEFAULT CURRENT_DATE(),
    RATED_BY               VARCHAR(50),
    RATING_REASON          VARCHAR(500),
    NEXT_REVIEW_DATE       DATE,
    PRIMARY KEY (RATING_ID)
);

-- ============================================================================
-- 3.5 REVIEW_QUEUE — Items awaiting analyst action
-- ============================================================================

CREATE OR REPLACE TABLE GENERIC_DB.COMPLIANCE.REVIEW_QUEUE (
    QUEUE_ID               VARCHAR(20)     NOT NULL,
    QUEUE_TYPE             VARCHAR(20)     NOT NULL,
    REFERENCE_ID           VARCHAR(20),
    PARTY_KEY              VARCHAR(15)     NOT NULL,
    PRIORITY               VARCHAR(10)     NOT NULL DEFAULT 'MEDIUM',
    STATUS                 VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    ASSIGNED_TO            VARCHAR(50),
    CREATED_AT             TIMESTAMP_NTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    DUE_DATE               DATE,
    DESCRIPTION            VARCHAR(500),
    PRIMARY KEY (QUEUE_ID)
);

-- ============================================================================
-- 3.6 AUDIT_LOG — All compliance actions taken
-- ============================================================================

CREATE OR REPLACE TABLE GENERIC_DB.COMPLIANCE.AUDIT_LOG (
    LOG_ID                 VARCHAR(20)     NOT NULL,
    ACTION_TYPE            VARCHAR(30)     NOT NULL,
    ENTITY_TYPE            VARCHAR(20)     NOT NULL,
    ENTITY_ID              VARCHAR(20),
    PARTY_KEY              VARCHAR(15),
    ACTION_BY              VARCHAR(50)     NOT NULL,
    ACTION_TS              TIMESTAMP_NTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    DETAILS                VARCHAR(2000),
    PRIMARY KEY (LOG_ID)
);

-- ============================================================================
-- 3.7 SEED DATA — SCREENING_RESULTS (~40 rows)
-- ============================================================================
-- Distribution: ~24 NO_MATCH, ~8 PARTIAL, ~3 CONFIRMED (EXACT), ~5 ESCALATED

INSERT INTO GENERIC_DB.COMPLIANCE.SCREENING_RESULTS
    (SCREENING_ID, PARTY_KEY, SCREENED_NAME, SCREENING_TYPE, MATCH_TYPE, MATCHED_LIST, MATCH_SCORE, RISK_CATEGORY, STATUS, SCREENED_BY, SCREENING_DATE, CLEARED_BY, CLEARED_AT, NOTES)
VALUES
    -- NO_MATCH results (24 rows)
    ('SCR-000001','PTY-000001','Meridian Capital Partners','SANCTIONS','NO_MATCH',NULL,3.20,NULL,'COMPLETED','ANALYST_JONES','2025-01-15 09:30:00',NULL,NULL,NULL),
    ('SCR-000002','PTY-000002','Nordic Timber Holdings','SANCTIONS','NO_MATCH',NULL,2.10,NULL,'COMPLETED','ANALYST_JONES','2025-01-15 09:31:00',NULL,NULL,NULL),
    ('SCR-000003','PTY-000003','Sakura Financial Group','SANCTIONS','NO_MATCH',NULL,5.40,NULL,'COMPLETED','ANALYST_PATEL','2025-01-16 10:00:00',NULL,NULL,NULL),
    ('SCR-000004','PTY-000004','Rhine Valley Industries','SANCTIONS','NO_MATCH',NULL,1.80,NULL,'COMPLETED','ANALYST_PATEL','2025-01-16 10:05:00',NULL,NULL,NULL),
    ('SCR-000005','PTY-000005','Pacific Rim Trading Co','SANCTIONS','NO_MATCH',NULL,4.50,NULL,'COMPLETED','ANALYST_CHEN','2025-01-17 08:20:00',NULL,NULL,NULL),
    ('SCR-000006','PTY-000006','Atlas Mining Corporation','SANCTIONS','NO_MATCH',NULL,2.90,NULL,'COMPLETED','ANALYST_CHEN','2025-01-17 08:25:00',NULL,NULL,NULL),
    ('SCR-000007','PTY-000008','Helios Energy Partners','SANCTIONS','NO_MATCH',NULL,6.10,NULL,'COMPLETED','ANALYST_JONES','2025-01-18 11:00:00',NULL,NULL,NULL),
    ('SCR-000008','PTY-000009','Pinnacle Reinsurance Ltd','SANCTIONS','NO_MATCH',NULL,3.70,NULL,'COMPLETED','ANALYST_PATEL','2025-01-18 11:15:00',NULL,NULL,NULL),
    ('SCR-000009','PTY-000010','Danube Shipping GmbH','SANCTIONS','NO_MATCH',NULL,1.20,NULL,'COMPLETED','ANALYST_CHEN','2025-01-19 09:00:00',NULL,NULL,NULL),
    ('SCR-000010','PTY-000011','Condor Aerospace Inc','SANCTIONS','NO_MATCH',NULL,4.80,NULL,'COMPLETED','ANALYST_JONES','2025-01-20 14:30:00',NULL,NULL,NULL),
    ('SCR-000011','PTY-000013','Silver Creek Ventures','SANCTIONS','NO_MATCH',NULL,2.30,NULL,'COMPLETED','ANALYST_PATEL','2025-01-21 09:45:00',NULL,NULL,NULL),
    ('SCR-000012','PTY-000014','Lighthouse Maritime Ltd','SANCTIONS','NO_MATCH',NULL,5.90,NULL,'COMPLETED','ANALYST_CHEN','2025-01-22 10:10:00',NULL,NULL,NULL),
    ('SCR-000013','PTY-000016','Orion Pharmaceuticals','SANCTIONS','NO_MATCH',NULL,3.40,NULL,'COMPLETED','ANALYST_JONES','2025-01-23 08:30:00',NULL,NULL,NULL),
    ('SCR-000014','PTY-000017','Falcon Logistics Group','SANCTIONS','NO_MATCH',NULL,1.60,NULL,'COMPLETED','ANALYST_PATEL','2025-01-24 11:20:00',NULL,NULL,NULL),
    ('SCR-000015','PTY-000019','Summit Asset Management','SANCTIONS','NO_MATCH',NULL,4.10,NULL,'COMPLETED','ANALYST_CHEN','2025-01-25 09:55:00',NULL,NULL,NULL),
    ('SCR-000016','PTY-000020','Terra Nova Resources','SANCTIONS','NO_MATCH',NULL,2.70,NULL,'COMPLETED','ANALYST_JONES','2025-01-26 13:40:00',NULL,NULL,NULL),
    ('SCR-000017','PTY-000022','Cascade Power Systems','SANCTIONS','NO_MATCH',NULL,6.30,NULL,'COMPLETED','ANALYST_PATEL','2025-01-27 10:00:00',NULL,NULL,NULL),
    ('SCR-000018','PTY-000024','Boreal Forest Products','SANCTIONS','NO_MATCH',NULL,3.10,NULL,'COMPLETED','ANALYST_CHEN','2025-01-28 08:15:00',NULL,NULL,NULL),
    ('SCR-000019','PTY-000026','Zenith Telecommunications','SANCTIONS','NO_MATCH',NULL,1.90,NULL,'COMPLETED','ANALYST_JONES','2025-01-29 09:30:00',NULL,NULL,NULL),
    ('SCR-000020','PTY-000028','Aegean Shipping Corp','SANCTIONS','NO_MATCH',NULL,5.20,NULL,'COMPLETED','ANALYST_PATEL','2025-01-30 14:00:00',NULL,NULL,NULL),
    ('SCR-000021','PTY-000030','Maple Leaf Financial','SANCTIONS','NO_MATCH',NULL,2.50,NULL,'COMPLETED','ANALYST_CHEN','2025-02-01 09:10:00',NULL,NULL,NULL),
    ('SCR-000022','PTY-000033','Alpine Defence Systems','SANCTIONS','NO_MATCH',NULL,4.60,NULL,'COMPLETED','ANALYST_JONES','2025-02-03 10:30:00',NULL,NULL,NULL),
    ('SCR-000023','PTY-000036','Coral Bay Developments','SANCTIONS','NO_MATCH',NULL,3.80,NULL,'COMPLETED','ANALYST_PATEL','2025-02-05 11:45:00',NULL,NULL,NULL),
    ('SCR-000024','PTY-000040','Horizon Digital Services','SANCTIONS','NO_MATCH',NULL,2.40,NULL,'COMPLETED','ANALYST_CHEN','2025-02-07 08:50:00',NULL,NULL,NULL),

    -- PARTIAL match results (8 rows)
    ('SCR-000025','PTY-000007','Caspian Trade Finance','SANCTIONS','PARTIAL','OFAC',42.50,'MONEY_LAUNDERING','CLEARED','ANALYST_JONES','2025-01-18 10:00:00','ANALYST_SENIOR_KIM','2025-01-20 16:00:00','Name similarity to listed entity Caspian Trading LLC. Cleared after review — different entity confirmed.'),
    ('SCR-000026','PTY-000012','Balkan Resource Partners','SANCTIONS','PARTIAL','EU_SANCTIONS',48.30,'SANCTIONS','CLEARED','ANALYST_PATEL','2025-01-21 09:00:00','ANALYST_SENIOR_KIM','2025-01-23 14:30:00','Partial name match to sanctioned Balkan Resources SA. Separate legal entity confirmed via corporate registry.'),
    ('SCR-000027','PTY-000018','Nile Valley Commodities','PEP','PARTIAL','PEP_LIST',55.20,'PEP','CLEARED','ANALYST_CHEN','2025-01-25 08:45:00','ANALYST_SENIOR_WONG','2025-01-28 11:00:00','Director name similar to PEP list entry. Confirmed different individual via date of birth verification.'),
    ('SCR-000028','PTY-000023','Indigo Textiles Pvt Ltd','SANCTIONS','PARTIAL','HMT',44.80,'SANCTIONS','CLEARED','ANALYST_JONES','2025-01-27 10:30:00','ANALYST_SENIOR_KIM','2025-01-30 09:15:00','Partial match to HMT consolidated list. Cleared — company operates in different sector.'),
    ('SCR-000029','PTY-000029','Tigris Petroleum Corp','SANCTIONS','PARTIAL','OFAC',58.90,'PROLIFERATION','OPEN','ANALYST_PATEL','2025-02-01 14:20:00',NULL,NULL,'Moderate match to OFAC SDN list entity. Under investigation — awaiting additional documentation.'),
    ('SCR-000030','PTY-000035','Silk Road Import Export','SANCTIONS','PARTIAL','UN_SCL',61.40,'TERRORISM','OPEN','ANALYST_CHEN','2025-02-04 09:00:00',NULL,NULL,'Name similarity to UN-listed entity. Enhanced due diligence initiated.'),
    ('SCR-000031','PTY-000042','Eastern Horizon Trading','SANCTIONS','PARTIAL','INTERNAL',46.70,'MONEY_LAUNDERING','CLEARED','ANALYST_JONES','2025-02-08 11:30:00','ANALYST_SENIOR_WONG','2025-02-10 15:45:00','Internal watchlist partial match. Reviewed transaction history — no suspicious patterns found.'),
    ('SCR-000032','PTY-000047','Crescent Bay Holdings','PEP','PARTIAL','PEP_LIST',52.10,'PEP','OPEN','ANALYST_PATEL','2025-02-12 10:00:00',NULL,NULL,'Beneficial owner name matches PEP database. Awaiting ownership verification documents.'),

    -- CONFIRMED hits / EXACT matches (3 rows)
    ('SCR-000033','PTY-000015','Volga International Trade','SANCTIONS','EXACT','OFAC',96.50,'SANCTIONS','CONFIRMED','ANALYST_CHEN','2025-01-22 09:30:00',NULL,NULL,'Exact match to OFAC SDN list. Entity confirmed as sanctioned. Account frozen pending compliance review.'),
    ('SCR-000034','PTY-000031','Euphrates Holdings Ltd','SANCTIONS','EXACT','EU_SANCTIONS',94.20,'TERRORISM','CONFIRMED','ANALYST_JONES','2025-02-02 10:15:00',NULL,NULL,'Confirmed match to EU terrorist financing list. All transactions suspended. SAR filed.'),
    ('SCR-000035','PTY-000044','Black Sea Commodities','SANCTIONS','EXACT','HMT',92.80,'SANCTIONS','CONFIRMED','ANALYST_PATEL','2025-02-10 08:45:00',NULL,NULL,'Exact match HMT sanctions list. Entity designated under Russia-related sanctions. Account restricted.'),

    -- ESCALATED (5 rows — FUZZY matches requiring further review)
    ('SCR-000036','PTY-000021','Caspian Energy Ventures','SANCTIONS','FUZZY','OFAC',72.40,'PROLIFERATION','ESCALATED','ANALYST_CHEN','2025-01-26 10:45:00',NULL,NULL,'Fuzzy match to proliferation-linked entity. Escalated to senior compliance officer for determination.'),
    ('SCR-000037','PTY-000025','Bosphorus Maritime Inc','SANCTIONS','FUZZY','UN_SCL',68.30,'TERRORISM','ESCALATED','ANALYST_JONES','2025-01-29 09:15:00',NULL,NULL,'Fuzzy match to UN Security Council list entry. Escalated for enhanced review.'),
    ('SCR-000038','PTY-000034','Danube Logistics Network','SANCTIONS','FUZZY','EU_SANCTIONS',75.60,'SANCTIONS','ESCALATED','ANALYST_PATEL','2025-02-04 14:00:00',NULL,NULL,'High fuzzy match score to sanctioned entity. Possible affiliated company. Escalated.'),
    ('SCR-000039','PTY-000038','Golden Triangle Exports','SANCTIONS','FUZZY','INTERNAL',70.10,'MONEY_LAUNDERING','ESCALATED','ANALYST_CHEN','2025-02-06 11:30:00',NULL,NULL,'Internal intelligence match. Possible connection to laundering network. Escalated for investigation.'),
    ('SCR-000040','PTY-000046','Levant Trading Partners','PEP','FUZZY','PEP_LIST',66.90,'PEP','ESCALATED','ANALYST_JONES','2025-02-11 09:00:00',NULL,NULL,'Multiple fuzzy matches to PEP database entries. Complex ownership structure. Escalated for EDD.');

-- ============================================================================
-- 3.8 SEED DATA — EDD_REVIEWS (~25 rows)
-- ============================================================================

INSERT INTO GENERIC_DB.COMPLIANCE.EDD_REVIEWS
    (REVIEW_ID, PARTY_KEY, REVIEW_TYPE, TRIGGER_REASON, STATUS, RISK_SCORE, ASSIGNED_TO, INITIATED_AT, COMPLETED_AT, DUE_DATE, FINDINGS, RECOMMENDATION, APPROVED_BY, APPROVED_AT)
VALUES
    -- COMPLETED reviews (10)
    ('EDD-000001','PTY-000007','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','COMPLETED',4,'ANALYST_JONES','2025-01-20 09:00:00','2025-02-05 16:30:00','2025-02-19','Partial OFAC match investigated. Entity confirmed as separate legal person from listed entity. No adverse media. Standard business operations verified.','APPROVE','SENIOR_KIM','2025-02-06 10:00:00'),
    ('EDD-000002','PTY-000012','ENHANCED_DUE_DILIGENCE','HIGH_RISK_JURISDICTION','COMPLETED',5,'ANALYST_PATEL','2025-01-22 10:15:00','2025-02-08 14:00:00','2025-02-21','Jurisdiction review completed. Entity operates in medium-risk region but has transparent corporate structure. Source of funds verified via audited financials.','APPROVE','SENIOR_WONG','2025-02-09 11:00:00'),
    ('EDD-000003','PTY-000015','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','COMPLETED',9,'ANALYST_CHEN','2025-01-23 08:30:00','2025-01-25 17:00:00','2025-02-22','Confirmed OFAC SDN match. Entity is designated under Iran sanctions program. Recommendation to terminate relationship and file SAR.','REJECT','SENIOR_KIM','2025-01-26 09:00:00'),
    ('EDD-000004','PTY-000018','ENHANCED_DUE_DILIGENCE','PEP','COMPLETED',6,'ANALYST_JONES','2025-01-26 11:00:00','2025-02-12 15:30:00','2025-02-25','PEP connection investigated. Director is former government official but left office 8 years ago. No ongoing political exposure. Enhanced monitoring recommended.','APPROVE','SENIOR_WONG','2025-02-13 09:30:00'),
    ('EDD-000005','PTY-000023','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','COMPLETED',3,'ANALYST_PATEL','2025-01-28 09:45:00','2025-02-10 11:00:00','2025-02-27','HMT partial match cleared. Different entity in different sector confirmed via Companies House records.','APPROVE','SENIOR_KIM','2025-02-11 10:00:00'),
    ('EDD-000006','PTY-000031','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','COMPLETED',10,'ANALYST_CHEN','2025-02-02 14:30:00','2025-02-04 09:00:00','2025-03-04','Confirmed EU terrorist financing list match. Immediate account freeze applied. SAR filed with FIU. Relationship termination in progress.','REJECT','SENIOR_KIM','2025-02-04 11:00:00'),
    ('EDD-000007','PTY-000042','ENHANCED_DUE_DILIGENCE','UNUSUAL_ACTIVITY','COMPLETED',4,'ANALYST_JONES','2025-02-09 10:00:00','2025-02-20 16:00:00','2025-03-11','Transaction pattern anomaly investigated. Spike in cross-border transfers explained by seasonal commodity purchases. Supporting documentation verified.','APPROVE','SENIOR_WONG','2025-02-21 09:00:00'),
    ('EDD-000008','PTY-000044','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','COMPLETED',9,'ANALYST_PATEL','2025-02-10 11:15:00','2025-02-12 14:00:00','2025-03-12','Confirmed HMT sanctions match. Russia-related designation. Account restricted, no new transactions permitted. Compliance hold applied.','REJECT','SENIOR_KIM','2025-02-12 16:00:00'),
    ('EDD-000009','PTY-000003','ENHANCED_DUE_DILIGENCE','PERIODIC','COMPLETED',2,'ANALYST_CHEN','2025-01-16 09:00:00','2025-01-30 11:00:00','2025-02-15','Annual periodic review. No changes to risk profile. Clean screening. Standard business activities confirmed.','APPROVE','SENIOR_WONG','2025-01-31 10:00:00'),
    ('EDD-000010','PTY-000010','ENHANCED_DUE_DILIGENCE','COMPLEX_STRUCTURE','COMPLETED',5,'ANALYST_JONES','2025-01-19 14:00:00','2025-02-03 10:30:00','2025-02-18','Multi-layered corporate structure reviewed. Ultimate beneficial ownership traced through 3 jurisdictions. All beneficial owners identified and verified.','APPROVE','SENIOR_KIM','2025-02-04 09:00:00'),

    -- IN_PROGRESS reviews (7)
    ('EDD-000011','PTY-000021','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','IN_PROGRESS',7,'ANALYST_PATEL','2025-02-14 09:00:00',NULL,'2025-03-16',NULL,NULL,NULL,NULL),
    ('EDD-000012','PTY-000025','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','IN_PROGRESS',6,'ANALYST_CHEN','2025-02-14 10:30:00',NULL,'2025-03-16',NULL,NULL,NULL,NULL),
    ('EDD-000013','PTY-000029','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','IN_PROGRESS',7,'ANALYST_JONES','2025-02-15 08:00:00',NULL,'2025-03-17',NULL,NULL,NULL,NULL),
    ('EDD-000014','PTY-000034','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','IN_PROGRESS',8,'ANALYST_PATEL','2025-02-15 11:00:00',NULL,'2025-03-17',NULL,NULL,NULL,NULL),
    ('EDD-000015','PTY-000035','ENHANCED_DUE_DILIGENCE','WATCHLIST_MATCH','IN_PROGRESS',7,'ANALYST_CHEN','2025-02-16 09:15:00',NULL,'2025-03-18',NULL,NULL,NULL,NULL),
    ('EDD-000016','PTY-000038','ENHANCED_DUE_DILIGENCE','UNUSUAL_ACTIVITY','IN_PROGRESS',8,'ANALYST_JONES','2025-02-16 14:00:00',NULL,'2025-03-18',NULL,NULL,NULL,NULL),
    ('EDD-000017','PTY-000046','ENHANCED_DUE_DILIGENCE','PEP','IN_PROGRESS',6,'ANALYST_PATEL','2025-02-17 10:00:00',NULL,'2025-03-19',NULL,NULL,NULL,NULL),

    -- PENDING reviews (4)
    ('EDD-000018','PTY-000047','ENHANCED_DUE_DILIGENCE','PEP','PENDING',5,NULL,'2025-02-18 09:00:00',NULL,'2025-03-20',NULL,NULL,NULL,NULL),
    ('EDD-000019','PTY-000039','ENHANCED_DUE_DILIGENCE','HIGH_RISK_JURISDICTION','PENDING',6,NULL,'2025-02-18 11:30:00',NULL,'2025-03-20',NULL,NULL,NULL,NULL),
    ('EDD-000020','PTY-000043','ENHANCED_DUE_DILIGENCE','COMPLEX_STRUCTURE','PENDING',5,NULL,'2025-02-19 08:45:00',NULL,'2025-03-21',NULL,NULL,NULL,NULL),
    ('EDD-000021','PTY-000048','ENHANCED_DUE_DILIGENCE','UNUSUAL_ACTIVITY','PENDING',6,NULL,'2025-02-19 10:00:00',NULL,'2025-03-21',NULL,NULL,NULL,NULL),

    -- OVERDUE reviews (4)
    ('EDD-000022','PTY-000027','ENHANCED_DUE_DILIGENCE','HIGH_RISK_JURISDICTION','OVERDUE',7,'ANALYST_CHEN','2025-01-05 09:00:00',NULL,'2025-02-04',NULL,NULL,NULL,NULL),
    ('EDD-000023','PTY-000032','ENHANCED_DUE_DILIGENCE','UNUSUAL_ACTIVITY','OVERDUE',8,'ANALYST_JONES','2025-01-08 10:30:00',NULL,'2025-02-07',NULL,NULL,NULL,NULL),
    ('EDD-000024','PTY-000037','ENHANCED_DUE_DILIGENCE','COMPLEX_STRUCTURE','OVERDUE',6,'ANALYST_PATEL','2025-01-10 14:00:00',NULL,'2025-02-09',NULL,NULL,NULL,NULL),
    ('EDD-000025','PTY-000041','ENHANCED_DUE_DILIGENCE','PERIODIC','OVERDUE',5,'ANALYST_CHEN','2025-01-12 09:30:00',NULL,'2025-02-11',NULL,NULL,NULL,NULL);

-- ============================================================================
-- 3.9 SEED DATA — PDD_SCHEDULE (50 rows — one per party)
-- ============================================================================
-- Distribution: ~30 ON_TRACK, ~8 DUE_SOON, ~7 OVERDUE, ~5 COMPLETED

INSERT INTO GENERIC_DB.COMPLIANCE.PDD_SCHEDULE
    (PDD_ID, PARTY_KEY, REVIEW_CYCLE, LAST_REVIEW_DATE, NEXT_REVIEW_DATE, STATUS, RISK_TIER, ASSIGNED_TO)
VALUES
    -- ON_TRACK (30 rows)
    ('PDD-000001','PTY-000001','ANNUAL','2024-11-15','2025-11-15','ON_TRACK','LOW','ANALYST_JONES'),
    ('PDD-000002','PTY-000002','ANNUAL','2024-10-20','2025-10-20','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000003','PTY-000003','ANNUAL','2025-01-30','2026-01-30','ON_TRACK','LOW','ANALYST_CHEN'),
    ('PDD-000004','PTY-000004','ANNUAL','2024-12-01','2025-12-01','ON_TRACK','LOW','ANALYST_JONES'),
    ('PDD-000005','PTY-000005','ANNUAL','2024-09-15','2025-09-15','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000006','PTY-000006','ANNUAL','2024-11-01','2025-11-01','ON_TRACK','LOW','ANALYST_CHEN'),
    ('PDD-000007','PTY-000008','ANNUAL','2024-10-10','2025-10-10','ON_TRACK','LOW','ANALYST_JONES'),
    ('PDD-000008','PTY-000009','ANNUAL','2024-12-20','2025-12-20','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000009','PTY-000010','SEMI_ANNUAL','2025-01-15','2025-07-15','ON_TRACK','MEDIUM','ANALYST_CHEN'),
    ('PDD-000010','PTY-000011','ANNUAL','2024-11-25','2025-11-25','ON_TRACK','LOW','ANALYST_JONES'),
    ('PDD-000011','PTY-000013','ANNUAL','2024-10-05','2025-10-05','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000012','PTY-000014','ANNUAL','2024-12-15','2025-12-15','ON_TRACK','LOW','ANALYST_CHEN'),
    ('PDD-000013','PTY-000016','ANNUAL','2025-01-20','2026-01-20','ON_TRACK','LOW','ANALYST_JONES'),
    ('PDD-000014','PTY-000017','ANNUAL','2024-09-30','2025-09-30','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000015','PTY-000019','ANNUAL','2024-11-10','2025-11-10','ON_TRACK','LOW','ANALYST_CHEN'),
    ('PDD-000016','PTY-000020','ANNUAL','2024-12-05','2025-12-05','ON_TRACK','LOW','ANALYST_JONES'),
    ('PDD-000017','PTY-000022','ANNUAL','2024-10-25','2025-10-25','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000018','PTY-000024','ANNUAL','2025-02-01','2026-02-01','ON_TRACK','LOW','ANALYST_CHEN'),
    ('PDD-000019','PTY-000026','ANNUAL','2024-11-20','2025-11-20','ON_TRACK','LOW','ANALYST_JONES'),
    ('PDD-000020','PTY-000028','ANNUAL','2024-12-10','2025-12-10','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000021','PTY-000030','ANNUAL','2024-10-15','2025-10-15','ON_TRACK','LOW','ANALYST_CHEN'),
    ('PDD-000022','PTY-000033','ANNUAL','2024-11-05','2025-11-05','ON_TRACK','LOW','ANALYST_JONES'),
    ('PDD-000023','PTY-000036','ANNUAL','2024-12-25','2025-12-25','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000024','PTY-000040','ANNUAL','2025-01-10','2026-01-10','ON_TRACK','LOW','ANALYST_CHEN'),
    ('PDD-000025','PTY-000042','SEMI_ANNUAL','2025-02-20','2025-08-20','ON_TRACK','MEDIUM','ANALYST_JONES'),
    ('PDD-000026','PTY-000045','ANNUAL','2024-10-30','2025-10-30','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000027','PTY-000048','SEMI_ANNUAL','2025-01-05','2025-07-05','ON_TRACK','MEDIUM','ANALYST_CHEN'),
    ('PDD-000028','PTY-000049','ANNUAL','2024-11-30','2025-11-30','ON_TRACK','LOW','ANALYST_JONES'),
    ('PDD-000029','PTY-000050','ANNUAL','2024-12-30','2025-12-30','ON_TRACK','LOW','ANALYST_PATEL'),
    ('PDD-000030','PTY-000018','SEMI_ANNUAL','2025-02-12','2025-08-12','ON_TRACK','MEDIUM','ANALYST_CHEN'),

    -- DUE_SOON (8 rows — next review within 30 days)
    ('PDD-000031','PTY-000007','SEMI_ANNUAL','2024-09-20','2025-03-20','DUE_SOON','MEDIUM','ANALYST_JONES'),
    ('PDD-000032','PTY-000012','SEMI_ANNUAL','2024-10-01','2025-04-01','DUE_SOON','MEDIUM','ANALYST_PATEL'),
    ('PDD-000033','PTY-000023','ANNUAL','2024-03-15','2025-03-15','DUE_SOON','LOW','ANALYST_CHEN'),
    ('PDD-000034','PTY-000029','QUARTERLY','2024-12-01','2025-03-01','DUE_SOON','HIGH','ANALYST_JONES'),
    ('PDD-000035','PTY-000035','QUARTERLY','2024-12-10','2025-03-10','DUE_SOON','HIGH','ANALYST_PATEL'),
    ('PDD-000036','PTY-000039','SEMI_ANNUAL','2024-09-25','2025-03-25','DUE_SOON','MEDIUM','ANALYST_CHEN'),
    ('PDD-000037','PTY-000043','ANNUAL','2024-03-20','2025-03-20','DUE_SOON','LOW','ANALYST_JONES'),
    ('PDD-000038','PTY-000047','SEMI_ANNUAL','2024-10-05','2025-04-05','DUE_SOON','MEDIUM','ANALYST_PATEL'),

    -- OVERDUE (7 rows — next review date has passed)
    ('PDD-000039','PTY-000015','QUARTERLY','2024-08-15','2024-11-15','OVERDUE','CRITICAL','ANALYST_CHEN'),
    ('PDD-000040','PTY-000021','QUARTERLY','2024-09-01','2024-12-01','OVERDUE','HIGH','ANALYST_JONES'),
    ('PDD-000041','PTY-000025','QUARTERLY','2024-09-10','2024-12-10','OVERDUE','HIGH','ANALYST_PATEL'),
    ('PDD-000042','PTY-000027','SEMI_ANNUAL','2024-05-01','2024-11-01','OVERDUE','MEDIUM','ANALYST_CHEN'),
    ('PDD-000043','PTY-000031','QUARTERLY','2024-08-01','2024-11-01','OVERDUE','CRITICAL','ANALYST_JONES'),
    ('PDD-000044','PTY-000034','QUARTERLY','2024-09-15','2024-12-15','OVERDUE','HIGH','ANALYST_PATEL'),
    ('PDD-000045','PTY-000037','SEMI_ANNUAL','2024-06-01','2024-12-01','OVERDUE','MEDIUM','ANALYST_CHEN'),

    -- COMPLETED (5 rows — recently completed reviews)
    ('PDD-000046','PTY-000032','SEMI_ANNUAL','2025-02-15','2025-08-15','COMPLETED','MEDIUM','ANALYST_JONES'),
    ('PDD-000047','PTY-000038','QUARTERLY','2025-02-10','2025-05-10','COMPLETED','HIGH','ANALYST_PATEL'),
    ('PDD-000048','PTY-000041','ANNUAL','2025-02-01','2026-02-01','COMPLETED','LOW','ANALYST_CHEN'),
    ('PDD-000049','PTY-000044','QUARTERLY','2025-02-12','2025-05-12','COMPLETED','CRITICAL','ANALYST_JONES'),
    ('PDD-000050','PTY-000046','SEMI_ANNUAL','2025-02-17','2025-08-17','COMPLETED','HIGH','ANALYST_PATEL');

-- ============================================================================
-- 3.10 SEED DATA — RISK_RATINGS (50 rows — one per party)
-- ============================================================================
-- Distribution: ~25 LOW, ~13 MEDIUM, ~7 HIGH, ~5 CRITICAL

INSERT INTO GENERIC_DB.COMPLIANCE.RISK_RATINGS
    (RATING_ID, PARTY_KEY, CURRENT_RATING, PREVIOUS_RATING, RATING_DATE, RATED_BY, RATING_REASON, NEXT_REVIEW_DATE)
VALUES
    -- LOW (25 rows)
    ('RTG-000001','PTY-000001','LOW',NULL,'2024-11-15','ANALYST_JONES','Initial onboarding assessment. Low-risk jurisdiction, transparent structure.','2025-11-15'),
    ('RTG-000002','PTY-000002','LOW',NULL,'2024-10-20','ANALYST_PATEL','Standard risk assessment. Established Nordic entity with clean history.','2025-10-20'),
    ('RTG-000003','PTY-000003','LOW',NULL,'2025-01-30','ANALYST_CHEN','Periodic review confirmed low risk. Regulated financial entity in Japan.','2026-01-30'),
    ('RTG-000004','PTY-000004','LOW',NULL,'2024-12-01','ANALYST_JONES','Initial assessment. EU-based industrial company, no adverse indicators.','2025-12-01'),
    ('RTG-000005','PTY-000005','LOW',NULL,'2024-09-15','ANALYST_PATEL','Standard assessment. Established Pacific Rim trader with clean screening.','2025-09-15'),
    ('RTG-000006','PTY-000006','LOW',NULL,'2024-11-01','ANALYST_CHEN','Low risk. Australian mining company, publicly listed, transparent governance.','2025-11-01'),
    ('RTG-000007','PTY-000008','LOW',NULL,'2024-10-10','ANALYST_JONES','Clean screening, standard risk profile. Renewable energy sector.','2025-10-10'),
    ('RTG-000008','PTY-000009','LOW',NULL,'2024-12-20','ANALYST_PATEL','Low risk. Licensed reinsurance entity in established jurisdiction.','2025-12-20'),
    ('RTG-000009','PTY-000011','LOW',NULL,'2024-11-25','ANALYST_CHEN','Standard assessment. US aerospace company, publicly listed.','2025-11-25'),
    ('RTG-000010','PTY-000013','LOW',NULL,'2024-10-05','ANALYST_JONES','Low risk. US-based venture capital firm, regulated entity.','2025-10-05'),
    ('RTG-000011','PTY-000014','LOW',NULL,'2024-12-15','ANALYST_PATEL','Low risk. Maritime company in low-risk jurisdiction.','2025-12-15'),
    ('RTG-000012','PTY-000016','LOW',NULL,'2025-01-20','ANALYST_CHEN','Standard assessment. Pharmaceutical company, well-regulated sector.','2026-01-20'),
    ('RTG-000013','PTY-000017','LOW',NULL,'2024-09-30','ANALYST_JONES','Low risk. Logistics company with transparent operations.','2025-09-30'),
    ('RTG-000014','PTY-000019','LOW',NULL,'2024-11-10','ANALYST_PATEL','Standard assessment. Regulated asset management firm.','2025-11-10'),
    ('RTG-000015','PTY-000020','LOW',NULL,'2024-12-05','ANALYST_CHEN','Low risk. Canadian natural resources company, publicly listed.','2025-12-05'),
    ('RTG-000016','PTY-000022','LOW',NULL,'2024-10-25','ANALYST_JONES','Standard assessment. Power systems company, EU-regulated.','2025-10-25'),
    ('RTG-000017','PTY-000024','LOW',NULL,'2025-02-01','ANALYST_PATEL','Low risk. Forest products company in Nordic jurisdiction.','2026-02-01'),
    ('RTG-000018','PTY-000026','LOW',NULL,'2024-11-20','ANALYST_CHEN','Standard assessment. Telecommunications company, publicly listed.','2025-11-20'),
    ('RTG-000019','PTY-000028','LOW',NULL,'2024-12-10','ANALYST_JONES','Low risk. Shipping company, Greek-flagged, established operations.','2025-12-10'),
    ('RTG-000020','PTY-000030','LOW',NULL,'2024-10-15','ANALYST_PATEL','Low risk. Canadian financial services, well-regulated.','2025-10-15'),
    ('RTG-000021','PTY-000033','LOW',NULL,'2024-11-05','ANALYST_CHEN','Standard assessment. Defence sector but in NATO jurisdiction.','2025-11-05'),
    ('RTG-000022','PTY-000036','LOW',NULL,'2024-12-25','ANALYST_JONES','Low risk. Property development in low-risk jurisdiction.','2025-12-25'),
    ('RTG-000023','PTY-000040','LOW',NULL,'2025-01-10','ANALYST_PATEL','Standard assessment. Digital services company, EU-based.','2026-01-10'),
    ('RTG-000024','PTY-000045','LOW',NULL,'2024-10-30','ANALYST_CHEN','Low risk. Technology company in established jurisdiction.','2025-10-30'),
    ('RTG-000025','PTY-000049','LOW',NULL,'2024-11-30','ANALYST_JONES','Standard assessment. Clean screening, low-risk profile.','2025-11-30'),

    -- MEDIUM (13 rows)
    ('RTG-000026','PTY-000007','MEDIUM','LOW','2025-01-20','ANALYST_JONES','Elevated due to partial OFAC match. Cleared but monitoring enhanced.','2025-07-20'),
    ('RTG-000027','PTY-000010','MEDIUM',NULL,'2025-01-15','ANALYST_CHEN','Complex multi-jurisdiction corporate structure. Enhanced monitoring.','2025-07-15'),
    ('RTG-000028','PTY-000012','MEDIUM','LOW','2025-01-22','ANALYST_PATEL','Elevated after partial EU sanctions match. Under enhanced monitoring.','2025-07-22'),
    ('RTG-000029','PTY-000018','MEDIUM','LOW','2025-01-26','ANALYST_JONES','PEP connection identified. Former government official as director.','2025-07-26'),
    ('RTG-000030','PTY-000023','MEDIUM',NULL,'2025-01-28','ANALYST_PATEL','HMT partial match cleared but medium risk due to operating region.','2025-07-28'),
    ('RTG-000031','PTY-000027','MEDIUM',NULL,'2024-05-01','ANALYST_CHEN','High-risk jurisdiction exposure. Enhanced monitoring required.','2024-11-01'),
    ('RTG-000032','PTY-000032','MEDIUM','LOW','2025-02-15','ANALYST_JONES','Unusual transaction patterns detected. Under enhanced monitoring.','2025-08-15'),
    ('RTG-000033','PTY-000037','MEDIUM',NULL,'2024-06-01','ANALYST_PATEL','Complex corporate structure across multiple jurisdictions.','2024-12-01'),
    ('RTG-000034','PTY-000039','MEDIUM',NULL,'2024-09-25','ANALYST_CHEN','High-risk jurisdiction. Enhanced monitoring.','2025-03-25'),
    ('RTG-000035','PTY-000041','MEDIUM','LOW','2025-02-01','ANALYST_JONES','Periodic review identified minor risk factors.','2026-02-01'),
    ('RTG-000036','PTY-000042','MEDIUM','LOW','2025-02-09','ANALYST_PATEL','Internal watchlist partial match. Cleared but monitoring enhanced.','2025-08-09'),
    ('RTG-000037','PTY-000043','MEDIUM',NULL,'2024-03-20','ANALYST_CHEN','Complex ownership structure requiring periodic verification.','2025-03-20'),
    ('RTG-000038','PTY-000050','MEDIUM',NULL,'2024-12-30','ANALYST_JONES','Operating in region with elevated corruption risk.','2025-06-30'),

    -- HIGH (7 rows)
    ('RTG-000039','PTY-000021','HIGH','MEDIUM','2025-01-26','ANALYST_CHEN','Fuzzy OFAC match with proliferation risk category. Under investigation.','2025-04-26'),
    ('RTG-000040','PTY-000025','HIGH','MEDIUM','2025-01-29','ANALYST_JONES','UN Security Council list fuzzy match. Enhanced review ongoing.','2025-04-29'),
    ('RTG-000041','PTY-000029','HIGH',NULL,'2025-02-01','ANALYST_PATEL','OFAC partial match under investigation. Petroleum sector risk.','2025-05-01'),
    ('RTG-000042','PTY-000034','HIGH','MEDIUM','2025-02-04','ANALYST_CHEN','High fuzzy match to sanctioned entity. Possible affiliation.','2025-05-04'),
    ('RTG-000043','PTY-000035','HIGH',NULL,'2025-02-04','ANALYST_PATEL','UN SCL partial match with terrorism risk category.','2025-05-04'),
    ('RTG-000044','PTY-000038','HIGH','MEDIUM','2025-02-06','ANALYST_JONES','Internal intelligence match. Money laundering investigation.','2025-05-06'),
    ('RTG-000045','PTY-000046','HIGH','MEDIUM','2025-02-11','ANALYST_PATEL','Multiple PEP matches. Complex ownership under review.','2025-05-11'),

    -- CRITICAL (5 rows)
    ('RTG-000046','PTY-000015','CRITICAL','HIGH','2025-01-23','ANALYST_CHEN','Confirmed OFAC SDN match. Account frozen. SAR filed.','2025-04-23'),
    ('RTG-000047','PTY-000031','CRITICAL','HIGH','2025-02-02','ANALYST_JONES','Confirmed EU terrorist financing list. Transactions suspended.','2025-05-02'),
    ('RTG-000048','PTY-000044','CRITICAL','HIGH','2025-02-10','ANALYST_PATEL','Confirmed HMT sanctions match. Account restricted.','2025-05-10'),
    ('RTG-000049','PTY-000047','CRITICAL','MEDIUM','2025-02-12','ANALYST_CHEN','PEP beneficial owner match. Crescent Bay Holdings under full review.','2025-05-12'),
    ('RTG-000050','PTY-000048','CRITICAL','MEDIUM','2025-02-18','ANALYST_JONES','Unusual activity combined with high-risk jurisdiction exposure.','2025-05-18');

-- ============================================================================
-- 3.11 SEED DATA — REVIEW_QUEUE (~20 open items)
-- ============================================================================

INSERT INTO GENERIC_DB.COMPLIANCE.REVIEW_QUEUE
    (QUEUE_ID, QUEUE_TYPE, REFERENCE_ID, PARTY_KEY, PRIORITY, STATUS, ASSIGNED_TO, CREATED_AT, DUE_DATE, DESCRIPTION)
VALUES
    -- EDD-related queue items
    ('RQ-000001','EDD','EDD-000011','PTY-000021','HIGH','IN_PROGRESS','ANALYST_PATEL','2025-02-14 09:00:00','2025-03-16','EDD review for fuzzy OFAC proliferation match'),
    ('RQ-000002','EDD','EDD-000012','PTY-000025','HIGH','IN_PROGRESS','ANALYST_CHEN','2025-02-14 10:30:00','2025-03-16','EDD review for UN SCL fuzzy match'),
    ('RQ-000003','EDD','EDD-000013','PTY-000029','HIGH','ASSIGNED','ANALYST_JONES','2025-02-15 08:00:00','2025-03-17','EDD review for OFAC partial match — petroleum sector'),
    ('RQ-000004','EDD','EDD-000014','PTY-000034','CRITICAL','IN_PROGRESS','ANALYST_PATEL','2025-02-15 11:00:00','2025-03-17','EDD review for high-score EU sanctions fuzzy match'),
    ('RQ-000005','EDD','EDD-000015','PTY-000035','HIGH','ASSIGNED','ANALYST_CHEN','2025-02-16 09:15:00','2025-03-18','EDD review for UN SCL partial match'),
    ('RQ-000006','EDD','EDD-000016','PTY-000038','CRITICAL','IN_PROGRESS','ANALYST_JONES','2025-02-16 14:00:00','2025-03-18','EDD review for internal intelligence match — ML investigation'),
    ('RQ-000007','EDD','EDD-000017','PTY-000046','HIGH','ASSIGNED','ANALYST_PATEL','2025-02-17 10:00:00','2025-03-19','EDD review for multiple PEP matches'),
    ('RQ-000008','EDD','EDD-000018','PTY-000047','HIGH','PENDING',NULL,'2025-02-18 09:00:00','2025-03-20','Pending EDD assignment for PEP beneficial owner match'),
    ('RQ-000009','EDD','EDD-000019','PTY-000039','MEDIUM','PENDING',NULL,'2025-02-18 11:30:00','2025-03-20','Pending EDD for high-risk jurisdiction'),

    -- SCREENING-related queue items
    ('RQ-000010','SCREENING',NULL,'PTY-000029','HIGH','PENDING',NULL,'2025-02-20 09:00:00','2025-02-27','Re-screening required — 90-day cycle for OFAC partial match party'),
    ('RQ-000011','SCREENING',NULL,'PTY-000035','HIGH','PENDING',NULL,'2025-02-20 09:05:00','2025-02-27','Re-screening required — UN SCL partial match party'),

    -- PDD-related queue items
    ('RQ-000012','PDD','PDD-000039','PTY-000015','CRITICAL','PENDING',NULL,'2025-02-15 08:00:00','2025-02-22','Overdue PDD for confirmed OFAC match party — CRITICAL'),
    ('RQ-000013','PDD','PDD-000040','PTY-000021','HIGH','ASSIGNED','ANALYST_JONES','2025-02-15 08:05:00','2025-02-22','Overdue PDD for high-risk OFAC fuzzy match party'),
    ('RQ-000014','PDD','PDD-000041','PTY-000025','HIGH','PENDING',NULL,'2025-02-15 08:10:00','2025-02-22','Overdue PDD for UN SCL fuzzy match party'),
    ('RQ-000015','PDD','PDD-000043','PTY-000031','CRITICAL','ASSIGNED','ANALYST_PATEL','2025-02-15 08:15:00','2025-02-22','Overdue PDD for confirmed EU terrorism match — CRITICAL'),

    -- RISK_ESCALATION queue items
    ('RQ-000016','RISK_ESCALATION','RISK-PTY-000047','PTY-000047','CRITICAL','PENDING',NULL,'2025-02-12 10:00:00','2025-02-19','Risk escalated to CRITICAL — PEP beneficial owner confirmed'),
    ('RQ-000017','RISK_ESCALATION','RISK-PTY-000048','PTY-000048','CRITICAL','ASSIGNED','ANALYST_CHEN','2025-02-18 09:00:00','2025-02-25','Risk escalated to CRITICAL — unusual activity + high-risk jurisdiction'),

    -- ESCALATION queue items
    ('RQ-000018','ESCALATION','SCR-000036','PTY-000021','HIGH','IN_PROGRESS','ANALYST_CHEN','2025-01-26 10:45:00','2025-02-09','Screening escalation — fuzzy OFAC proliferation match'),
    ('RQ-000019','ESCALATION','SCR-000037','PTY-000025','HIGH','IN_PROGRESS','ANALYST_JONES','2025-01-29 09:15:00','2025-02-12','Screening escalation — fuzzy UN SCL terrorism match'),
    ('RQ-000020','ESCALATION','EDD-000022','PTY-000027','MEDIUM','PENDING',NULL,'2025-02-05 09:00:00','2025-02-19','Overdue EDD escalation — high-risk jurisdiction review stalled');

-- ============================================================================
-- 3.12 SEED DATA — AUDIT_LOG (~60 rows)
-- ============================================================================

INSERT INTO GENERIC_DB.COMPLIANCE.AUDIT_LOG
    (LOG_ID, ACTION_TYPE, ENTITY_TYPE, ENTITY_ID, PARTY_KEY, ACTION_BY, ACTION_TS, DETAILS)
VALUES
    -- Screening runs
    ('AUD-000001','SCREENING_RUN','PARTY','SCR-000001','PTY-000001','ANALYST_JONES','2025-01-15 09:30:00','Screening completed. Match: NO_MATCH. Score: 3.20'),
    ('AUD-000002','SCREENING_RUN','PARTY','SCR-000002','PTY-000002','ANALYST_JONES','2025-01-15 09:31:00','Screening completed. Match: NO_MATCH. Score: 2.10'),
    ('AUD-000003','SCREENING_RUN','PARTY','SCR-000003','PTY-000003','ANALYST_PATEL','2025-01-16 10:00:00','Screening completed. Match: NO_MATCH. Score: 5.40'),
    ('AUD-000004','SCREENING_RUN','PARTY','SCR-000007','PTY-000008','ANALYST_JONES','2025-01-18 11:00:00','Screening completed. Match: NO_MATCH. Score: 6.10'),
    ('AUD-000005','SCREENING_RUN','PARTY','SCR-000025','PTY-000007','ANALYST_JONES','2025-01-18 10:00:00','Screening completed. Match: PARTIAL. Score: 42.50. List: OFAC'),
    ('AUD-000006','SCREENING_RUN','PARTY','SCR-000026','PTY-000012','ANALYST_PATEL','2025-01-21 09:00:00','Screening completed. Match: PARTIAL. Score: 48.30. List: EU_SANCTIONS'),
    ('AUD-000007','SCREENING_RUN','PARTY','SCR-000033','PTY-000015','ANALYST_CHEN','2025-01-22 09:30:00','Screening completed. Match: EXACT. Score: 96.50. List: OFAC. CONFIRMED HIT.'),
    ('AUD-000008','SCREENING_RUN','PARTY','SCR-000027','PTY-000018','ANALYST_CHEN','2025-01-25 08:45:00','Screening completed. Match: PARTIAL. Score: 55.20. List: PEP_LIST'),
    ('AUD-000009','SCREENING_RUN','PARTY','SCR-000036','PTY-000021','ANALYST_CHEN','2025-01-26 10:45:00','Screening completed. Match: FUZZY. Score: 72.40. List: OFAC. ESCALATED.'),
    ('AUD-000010','SCREENING_RUN','PARTY','SCR-000037','PTY-000025','ANALYST_JONES','2025-01-29 09:15:00','Screening completed. Match: FUZZY. Score: 68.30. List: UN_SCL. ESCALATED.'),
    ('AUD-000011','SCREENING_RUN','PARTY','SCR-000034','PTY-000031','ANALYST_JONES','2025-02-02 10:15:00','Screening completed. Match: EXACT. Score: 94.20. List: EU_SANCTIONS. CONFIRMED HIT.'),
    ('AUD-000012','SCREENING_RUN','PARTY','SCR-000038','PTY-000034','ANALYST_PATEL','2025-02-04 14:00:00','Screening completed. Match: FUZZY. Score: 75.60. List: EU_SANCTIONS. ESCALATED.'),
    ('AUD-000013','SCREENING_RUN','PARTY','SCR-000035','PTY-000044','ANALYST_PATEL','2025-02-10 08:45:00','Screening completed. Match: EXACT. Score: 92.80. List: HMT. CONFIRMED HIT.'),
    ('AUD-000014','SCREENING_RUN','PARTY','SCR-000040','PTY-000046','ANALYST_JONES','2025-02-11 09:00:00','Screening completed. Match: FUZZY. Score: 66.90. List: PEP_LIST. ESCALATED.'),
    ('AUD-000015','SCREENING_RUN','PARTY','SCR-000032','PTY-000047','ANALYST_PATEL','2025-02-12 10:00:00','Screening completed. Match: PARTIAL. Score: 52.10. List: PEP_LIST'),

    -- EDD initiated
    ('AUD-000016','EDD_INITIATED','REVIEW','EDD-000001','PTY-000007','ANALYST_JONES','2025-01-20 09:00:00','EDD review initiated. Trigger: WATCHLIST_MATCH. Due: 2025-02-19'),
    ('AUD-000017','EDD_INITIATED','REVIEW','EDD-000002','PTY-000012','ANALYST_PATEL','2025-01-22 10:15:00','EDD review initiated. Trigger: HIGH_RISK_JURISDICTION. Due: 2025-02-21'),
    ('AUD-000018','EDD_INITIATED','REVIEW','EDD-000003','PTY-000015','ANALYST_CHEN','2025-01-23 08:30:00','EDD review initiated. Trigger: WATCHLIST_MATCH — OFAC confirmed hit. Priority: CRITICAL'),
    ('AUD-000019','EDD_INITIATED','REVIEW','EDD-000004','PTY-000018','ANALYST_JONES','2025-01-26 11:00:00','EDD review initiated. Trigger: PEP. Due: 2025-02-25'),
    ('AUD-000020','EDD_INITIATED','REVIEW','EDD-000006','PTY-000031','ANALYST_CHEN','2025-02-02 14:30:00','EDD review initiated. Trigger: WATCHLIST_MATCH — EU terrorism confirmed. Priority: CRITICAL'),
    ('AUD-000021','EDD_INITIATED','REVIEW','EDD-000011','PTY-000021','ANALYST_PATEL','2025-02-14 09:00:00','EDD review initiated. Trigger: WATCHLIST_MATCH. Due: 2025-03-16'),
    ('AUD-000022','EDD_INITIATED','REVIEW','EDD-000012','PTY-000025','ANALYST_CHEN','2025-02-14 10:30:00','EDD review initiated. Trigger: WATCHLIST_MATCH. Due: 2025-03-16'),
    ('AUD-000023','EDD_INITIATED','REVIEW','EDD-000013','PTY-000029','ANALYST_JONES','2025-02-15 08:00:00','EDD review initiated. Trigger: WATCHLIST_MATCH. Due: 2025-03-17'),
    ('AUD-000024','EDD_INITIATED','REVIEW','EDD-000016','PTY-000038','ANALYST_JONES','2025-02-16 14:00:00','EDD review initiated. Trigger: UNUSUAL_ACTIVITY. Due: 2025-03-18'),
    ('AUD-000025','EDD_INITIATED','REVIEW','EDD-000017','PTY-000046','ANALYST_PATEL','2025-02-17 10:00:00','EDD review initiated. Trigger: PEP. Due: 2025-03-19'),

    -- EDD completed
    ('AUD-000026','EDD_COMPLETED','REVIEW','EDD-000001','PTY-000007','ANALYST_JONES','2025-02-05 16:30:00','EDD completed. Decision: APPROVE. Partial OFAC match cleared — separate entity confirmed.'),
    ('AUD-000027','EDD_COMPLETED','REVIEW','EDD-000002','PTY-000012','ANALYST_PATEL','2025-02-08 14:00:00','EDD completed. Decision: APPROVE. Jurisdiction risk acceptable, transparent structure.'),
    ('AUD-000028','EDD_COMPLETED','REVIEW','EDD-000003','PTY-000015','ANALYST_CHEN','2025-01-25 17:00:00','EDD completed. Decision: REJECT. Confirmed OFAC SDN match. SAR filed.'),
    ('AUD-000029','EDD_COMPLETED','REVIEW','EDD-000004','PTY-000018','ANALYST_JONES','2025-02-12 15:30:00','EDD completed. Decision: APPROVE. Former PEP, no ongoing exposure.'),
    ('AUD-000030','EDD_COMPLETED','REVIEW','EDD-000006','PTY-000031','ANALYST_CHEN','2025-02-04 09:00:00','EDD completed. Decision: REJECT. EU terrorist financing confirmed. Account frozen.'),
    ('AUD-000031','EDD_COMPLETED','REVIEW','EDD-000007','PTY-000042','ANALYST_JONES','2025-02-20 16:00:00','EDD completed. Decision: APPROVE. Transaction anomaly explained by seasonal activity.'),
    ('AUD-000032','EDD_COMPLETED','REVIEW','EDD-000008','PTY-000044','ANALYST_PATEL','2025-02-12 14:00:00','EDD completed. Decision: REJECT. Confirmed HMT sanctions match.'),
    ('AUD-000033','EDD_COMPLETED','REVIEW','EDD-000009','PTY-000003','ANALYST_CHEN','2025-01-30 11:00:00','EDD completed. Decision: APPROVE. Periodic review, no changes to risk profile.'),
    ('AUD-000034','EDD_COMPLETED','REVIEW','EDD-000010','PTY-000010','ANALYST_JONES','2025-02-03 10:30:00','EDD completed. Decision: APPROVE. UBO traced and verified across 3 jurisdictions.'),

    -- Risk updated
    ('AUD-000035','RISK_UPDATED','PARTY','RTG-000026','PTY-000007','ANALYST_JONES','2025-01-20 09:30:00','Rating changed from LOW to MEDIUM. Reason: Partial OFAC match — enhanced monitoring.'),
    ('AUD-000036','RISK_UPDATED','PARTY','RTG-000028','PTY-000012','ANALYST_PATEL','2025-01-22 10:30:00','Rating changed from LOW to MEDIUM. Reason: Partial EU sanctions match.'),
    ('AUD-000037','RISK_UPDATED','PARTY','RTG-000046','PTY-000015','ANALYST_CHEN','2025-01-23 09:00:00','Rating changed from HIGH to CRITICAL. Reason: Confirmed OFAC SDN match.'),
    ('AUD-000038','RISK_UPDATED','PARTY','RTG-000029','PTY-000018','ANALYST_JONES','2025-01-26 11:30:00','Rating changed from LOW to MEDIUM. Reason: PEP connection identified.'),
    ('AUD-000039','RISK_UPDATED','PARTY','RTG-000039','PTY-000021','ANALYST_CHEN','2025-01-26 11:00:00','Rating changed from MEDIUM to HIGH. Reason: Fuzzy OFAC proliferation match.'),
    ('AUD-000040','RISK_UPDATED','PARTY','RTG-000040','PTY-000025','ANALYST_JONES','2025-01-29 09:30:00','Rating changed from MEDIUM to HIGH. Reason: UN SCL fuzzy match.'),
    ('AUD-000041','RISK_UPDATED','PARTY','RTG-000047','PTY-000031','ANALYST_JONES','2025-02-02 10:30:00','Rating changed from HIGH to CRITICAL. Reason: Confirmed EU terrorism list.'),
    ('AUD-000042','RISK_UPDATED','PARTY','RTG-000042','PTY-000034','ANALYST_CHEN','2025-02-04 14:30:00','Rating changed from MEDIUM to HIGH. Reason: High EU sanctions fuzzy match.'),
    ('AUD-000043','RISK_UPDATED','PARTY','RTG-000044','PTY-000038','ANALYST_JONES','2025-02-06 12:00:00','Rating changed from MEDIUM to HIGH. Reason: Internal intelligence ML match.'),
    ('AUD-000044','RISK_UPDATED','PARTY','RTG-000048','PTY-000044','ANALYST_PATEL','2025-02-10 09:00:00','Rating changed from HIGH to CRITICAL. Reason: Confirmed HMT sanctions.'),
    ('AUD-000045','RISK_UPDATED','PARTY','RTG-000045','PTY-000046','ANALYST_PATEL','2025-02-11 09:30:00','Rating changed from MEDIUM to HIGH. Reason: Multiple PEP matches.'),
    ('AUD-000046','RISK_UPDATED','PARTY','RTG-000049','PTY-000047','ANALYST_CHEN','2025-02-12 10:30:00','Rating changed from MEDIUM to CRITICAL. Reason: PEP beneficial owner confirmed.'),
    ('AUD-000047','RISK_UPDATED','PARTY','RTG-000050','PTY-000048','ANALYST_JONES','2025-02-18 09:30:00','Rating changed from MEDIUM to CRITICAL. Reason: Unusual activity + high-risk jurisdiction.'),

    -- PDD completed
    ('AUD-000048','PDD_COMPLETED','PARTY','PDD-000046','PTY-000032','ANALYST_JONES','2025-02-15 16:00:00','Periodic review completed. Risk remains MEDIUM. Next review: 2025-08-15.'),
    ('AUD-000049','PDD_COMPLETED','PARTY','PDD-000047','PTY-000038','ANALYST_PATEL','2025-02-10 15:30:00','Quarterly PDD completed. HIGH risk confirmed. Next review: 2025-05-10.'),
    ('AUD-000050','PDD_COMPLETED','PARTY','PDD-000048','PTY-000041','ANALYST_CHEN','2025-02-01 14:00:00','Annual PDD completed. Risk downgraded context reviewed. Next review: 2026-02-01.'),
    ('AUD-000051','PDD_COMPLETED','PARTY','PDD-000049','PTY-000044','ANALYST_JONES','2025-02-12 16:00:00','Quarterly PDD completed. CRITICAL — sanctions confirmed. Next review: 2025-05-12.'),
    ('AUD-000052','PDD_COMPLETED','PARTY','PDD-000050','PTY-000046','ANALYST_PATEL','2025-02-17 16:30:00','Semi-annual PDD completed. HIGH risk. Multiple PEP matches. Next review: 2025-08-17.'),

    -- Escalations
    ('AUD-000053','ESCALATION','SCREENING','SCR-000036','PTY-000021','ANALYST_CHEN','2025-01-26 11:00:00','Screening escalated to senior compliance. Fuzzy OFAC match — proliferation category.'),
    ('AUD-000054','ESCALATION','SCREENING','SCR-000037','PTY-000025','ANALYST_JONES','2025-01-29 09:30:00','Screening escalated. Fuzzy UN SCL match — terrorism category.'),
    ('AUD-000055','ESCALATION','SCREENING','SCR-000038','PTY-000034','ANALYST_PATEL','2025-02-04 14:30:00','Screening escalated. High fuzzy match to EU sanctioned entity.'),
    ('AUD-000056','ESCALATION','SCREENING','SCR-000039','PTY-000038','ANALYST_CHEN','2025-02-06 12:00:00','Screening escalated. Internal intelligence match — ML network.'),
    ('AUD-000057','ESCALATION','SCREENING','SCR-000040','PTY-000046','ANALYST_JONES','2025-02-11 09:30:00','Screening escalated. Multiple PEP fuzzy matches — complex ownership.'),

    -- Notes added
    ('AUD-000058','NOTE_ADDED','PARTY',NULL,'PTY-000015','SENIOR_KIM','2025-01-26 09:30:00','SAR-2025-0015 filed with FIU. Account frozen as of 2025-01-23. All outbound transactions blocked.'),
    ('AUD-000059','NOTE_ADDED','PARTY',NULL,'PTY-000031','SENIOR_KIM','2025-02-04 12:00:00','SAR-2025-0031 filed with FIU. EU terrorism financing confirmed. Coordinating with EU authorities via FIU.'),
    ('AUD-000060','NOTE_ADDED','PARTY',NULL,'PTY-000044','SENIOR_WONG','2025-02-12 16:30:00','Account restricted under HMT Russia sanctions. Compliance hold applied. No new credits permitted.');

-- ============================================================================
-- 3.13 VERIFICATION
-- ============================================================================

SELECT 'SCREENING_RESULTS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM GENERIC_DB.COMPLIANCE.SCREENING_RESULTS
UNION ALL
SELECT 'EDD_REVIEWS', COUNT(*) FROM GENERIC_DB.COMPLIANCE.EDD_REVIEWS
UNION ALL
SELECT 'PDD_SCHEDULE', COUNT(*) FROM GENERIC_DB.COMPLIANCE.PDD_SCHEDULE
UNION ALL
SELECT 'RISK_RATINGS', COUNT(*) FROM GENERIC_DB.COMPLIANCE.RISK_RATINGS
UNION ALL
SELECT 'REVIEW_QUEUE', COUNT(*) FROM GENERIC_DB.COMPLIANCE.REVIEW_QUEUE
UNION ALL
SELECT 'AUDIT_LOG', COUNT(*) FROM GENERIC_DB.COMPLIANCE.AUDIT_LOG
ORDER BY TABLE_NAME;

SELECT 'Compliance tables created and seeded! Run 04_semantic_views.sql next.' AS STATUS;
