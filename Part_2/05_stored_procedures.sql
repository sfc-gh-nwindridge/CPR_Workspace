/*=============================================================================
  COMPLIANCE AGENT WORKSHOP - STEP 5: STORED PROCEDURES (AGENT TOOLS)
  ===========================================================================
  Creates deterministic stored procedures that Cortex Agents can invoke as
  custom tools. Each procedure performs a specific compliance action:
  screening, EDD initiation, review completion, risk updates, and more.

  Prerequisites: Run 01_setup.sql, 02_seed_data.sql, 03_compliance_tables.sql
  Run as: CPR_WORKSHOP_ROLE
  ===========================================================================*/

-- ============================================================================
-- 5.0 ROLE & WAREHOUSE
-- ============================================================================

USE ROLE CPR_WORKSHOP_ROLE;
USE WAREHOUSE CPR_WORKSHOP_WH;
USE SCHEMA GENERIC_DB.COMPLIANCE;

-- ============================================================================
-- 5.1 SP_RUN_SCREENING — Run watchlist/sanctions screening for a party
-- ============================================================================
-- Simulates name screening by looking up the party and generating a weighted
-- random match outcome. Logs result to SCREENING_RESULTS and AUDIT_LOG.

CREATE OR REPLACE PROCEDURE GENERIC_DB.COMPLIANCE.SP_RUN_SCREENING(
    P_PARTY_KEY VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET v_party_name VARCHAR;
    LET v_screening_id VARCHAR;
    LET v_match_type VARCHAR;
    LET v_score NUMBER(5,2);
    LET v_rand NUMBER(5,2);

    -- Look up party name
    SELECT PARTY_NAME INTO :v_party_name
    FROM GENERIC_DB.PARTY_MART.PARTY_PROFILE_CURRENT
    WHERE PARTY_PROFILE_ID = :P_PARTY_KEY
    LIMIT 1;

    IF (v_party_name IS NULL) THEN
        RETURN 'ERROR: Party not found for key ' || :P_PARTY_KEY;
    END IF;

    -- Generate screening ID
    v_screening_id := 'SCR-' || TO_VARCHAR(UNIFORM(100000, 999999, RANDOM()));

    -- Weighted random match outcome: 70% NO_MATCH, 20% PARTIAL, 7% FUZZY, 3% EXACT
    v_rand := UNIFORM(0::FLOAT, 1::FLOAT, RANDOM());
    IF (v_rand < 0.70) THEN
        v_match_type := 'NO_MATCH';
        v_score := UNIFORM(0::FLOAT, 15::FLOAT, RANDOM());
    ELSEIF (v_rand < 0.90) THEN
        v_match_type := 'PARTIAL';
        v_score := UNIFORM(40::FLOAT, 65::FLOAT, RANDOM());
    ELSEIF (v_rand < 0.97) THEN
        v_match_type := 'FUZZY';
        v_score := UNIFORM(65::FLOAT, 85::FLOAT, RANDOM());
    ELSE
        v_match_type := 'EXACT';
        v_score := UNIFORM(90::FLOAT, 100::FLOAT, RANDOM());
    END IF;

    -- Insert screening result
    INSERT INTO GENERIC_DB.COMPLIANCE.SCREENING_RESULTS (
        SCREENING_ID, PARTY_KEY, SCREENED_NAME, SCREENING_TYPE,
        MATCH_TYPE, MATCH_SCORE, SCREENING_DATE, STATUS, SCREENED_BY
    ) VALUES (
        :v_screening_id, :P_PARTY_KEY, :v_party_name, 'SANCTIONS',
        :v_match_type, :v_score, CURRENT_TIMESTAMP(), 'COMPLETED', 'CORTEX_AGENT'
    );

    -- Log to audit
    INSERT INTO GENERIC_DB.COMPLIANCE.AUDIT_LOG (
        LOG_ID, ACTION_TYPE, ENTITY_TYPE, ENTITY_ID,
        ACTION_BY, ACTION_TS, DETAILS
    ) VALUES (
        'AUD-' || TO_VARCHAR(UNIFORM(100000, 999999, RANDOM())),
        'SCREENING_RUN', 'PARTY', :P_PARTY_KEY,
        'CORTEX_AGENT', CURRENT_TIMESTAMP(),
        'Screening ' || :v_screening_id || ' completed. Match: ' || :v_match_type || ' Score: ' || TO_VARCHAR(:v_score)
    );

    RETURN 'Screening complete for ' || :v_party_name || '. Result: ' || :v_match_type || '. Score: ' || TO_VARCHAR(:v_score) || '.';
END;

-- ============================================================================
-- 5.2 SP_INITIATE_EDD — Create an Enhanced Due Diligence review
-- ============================================================================
-- Creates an EDD review record and adds an entry to the review queue.

CREATE OR REPLACE PROCEDURE GENERIC_DB.COMPLIANCE.SP_INITIATE_EDD(
    P_PARTY_KEY VARCHAR,
    P_TRIGGER_REASON VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET v_review_id VARCHAR;
    LET v_due_date DATE;
    LET v_priority VARCHAR;

    -- Generate review ID
    v_review_id := 'EDD-' || TO_VARCHAR(UNIFORM(100000, 999999, RANDOM()));

    -- Due date is 30 days from now
    v_due_date := DATEADD(DAY, 30, CURRENT_DATE());

    -- Priority based on trigger reason
    CASE
        WHEN UPPER(:P_TRIGGER_REASON) LIKE '%SANCTION%' OR UPPER(:P_TRIGGER_REASON) LIKE '%EXACT%' THEN
            v_priority := 'CRITICAL';
        WHEN UPPER(:P_TRIGGER_REASON) LIKE '%PEP%' OR UPPER(:P_TRIGGER_REASON) LIKE '%HIGH%' THEN
            v_priority := 'HIGH';
        WHEN UPPER(:P_TRIGGER_REASON) LIKE '%FUZZY%' OR UPPER(:P_TRIGGER_REASON) LIKE '%PARTIAL%' THEN
            v_priority := 'MEDIUM';
        ELSE
            v_priority := 'NORMAL';
    END CASE;

    -- Create EDD review record
    INSERT INTO GENERIC_DB.COMPLIANCE.EDD_REVIEWS (
        REVIEW_ID, PARTY_KEY, REVIEW_TYPE, TRIGGER_REASON,
        STATUS, ASSIGNED_TO, INITIATED_AT, DUE_DATE
    ) VALUES (
        :v_review_id, :P_PARTY_KEY, 'ENHANCED_DUE_DILIGENCE', :P_TRIGGER_REASON,
        'PENDING', NULL, CURRENT_TIMESTAMP(), :v_due_date
    );

    -- Add to review queue
    INSERT INTO GENERIC_DB.COMPLIANCE.REVIEW_QUEUE (
        QUEUE_ID, QUEUE_TYPE, REFERENCE_ID, PARTY_KEY,
        PRIORITY, STATUS, CREATED_AT
    ) VALUES (
        'RQ-' || TO_VARCHAR(UNIFORM(100000, 999999, RANDOM())),
        'EDD', :v_review_id, :P_PARTY_KEY,
        :v_priority, 'PENDING', CURRENT_TIMESTAMP()
    );

    -- Log to audit
    INSERT INTO GENERIC_DB.COMPLIANCE.AUDIT_LOG (
        LOG_ID, ACTION_TYPE, ENTITY_TYPE, ENTITY_ID,
        ACTION_BY, ACTION_TS, DETAILS
    ) VALUES (
        'AUD-' || TO_VARCHAR(UNIFORM(100000, 999999, RANDOM())),
        'EDD_INITIATED', 'REVIEW', :v_review_id,
        'CORTEX_AGENT', CURRENT_TIMESTAMP(),
        'EDD review initiated for party ' || :P_PARTY_KEY || '. Trigger: ' || :P_TRIGGER_REASON || '. Priority: ' || :v_priority
    );

    RETURN 'EDD review ' || :v_review_id || ' initiated for party ' || :P_PARTY_KEY || '. Trigger: ' || :P_TRIGGER_REASON || '. Due: ' || TO_VARCHAR(:v_due_date) || '.';
END;

-- ============================================================================
-- 5.3 SP_COMPLETE_REVIEW — Close out a review with a decision
-- ============================================================================
-- Updates an EDD review as completed and adjusts risk ratings if needed.

CREATE OR REPLACE PROCEDURE GENERIC_DB.COMPLIANCE.SP_COMPLETE_REVIEW(
    P_REVIEW_ID VARCHAR,
    P_DECISION VARCHAR,
    P_NOTES VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET v_party_key VARCHAR;

    -- Look up the party key from the review
    SELECT PARTY_KEY INTO :v_party_key
    FROM GENERIC_DB.COMPLIANCE.EDD_REVIEWS
    WHERE REVIEW_ID = :P_REVIEW_ID
    LIMIT 1;

    IF (v_party_key IS NULL) THEN
        RETURN 'ERROR: Review not found for ID ' || :P_REVIEW_ID;
    END IF;

    -- Update the EDD review
    UPDATE GENERIC_DB.COMPLIANCE.EDD_REVIEWS
    SET STATUS = 'COMPLETED',
        RECOMMENDATION = :P_DECISION,
        FINDINGS = :P_NOTES,
        COMPLETED_AT = CURRENT_TIMESTAMP()
    WHERE REVIEW_ID = :P_REVIEW_ID;

    -- If decision is REJECT or ESCALATE, increase risk rating
    IF (UPPER(:P_DECISION) IN ('REJECT', 'ESCALATE')) THEN
        UPDATE GENERIC_DB.COMPLIANCE.RISK_RATINGS
        SET PREVIOUS_RATING = CURRENT_RATING,
            CURRENT_RATING = CASE
                WHEN CURRENT_RATING = 'LOW' THEN 'MEDIUM'
                WHEN CURRENT_RATING = 'MEDIUM' THEN 'HIGH'
                WHEN CURRENT_RATING = 'HIGH' THEN 'CRITICAL'
                ELSE CURRENT_RATING
            END,
            RATING_DATE = CURRENT_DATE(),
            RATING_REASON = 'Escalated via review ' || :P_REVIEW_ID || ': ' || :P_DECISION
        WHERE PARTY_KEY = :v_party_key;
    END IF;

    -- Mark review queue entry as completed
    UPDATE GENERIC_DB.COMPLIANCE.REVIEW_QUEUE
    SET STATUS = 'COMPLETED'
    WHERE REFERENCE_ID = :P_REVIEW_ID;

    -- Log to audit
    INSERT INTO GENERIC_DB.COMPLIANCE.AUDIT_LOG (
        LOG_ID, ACTION_TYPE, ENTITY_TYPE, ENTITY_ID,
        ACTION_BY, ACTION_TS, DETAILS
    ) VALUES (
        'AUD-' || TO_VARCHAR(UNIFORM(100000, 999999, RANDOM())),
        'REVIEW_COMPLETED', 'REVIEW', :P_REVIEW_ID,
        'CORTEX_AGENT', CURRENT_TIMESTAMP(),
        'Review completed. Decision: ' || :P_DECISION || '. Party: ' || :v_party_key || '. Notes: ' || :P_NOTES
    );

    RETURN 'Review ' || :P_REVIEW_ID || ' completed. Decision: ' || :P_DECISION || '.';
END;

-- ============================================================================
-- 5.4 SP_GET_PDD_OVERDUE — List parties with overdue periodic reviews
-- ============================================================================
-- Returns a table of parties whose next review date has passed.

CREATE OR REPLACE PROCEDURE GENERIC_DB.COMPLIANCE.SP_GET_PDD_OVERDUE()
RETURNS TABLE (
    PARTY_KEY VARCHAR,
    PARTY_NAME VARCHAR,
    REVIEW_CYCLE VARCHAR,
    NEXT_REVIEW_DATE DATE,
    DAYS_OVERDUE NUMBER,
    CURRENT_RISK VARCHAR
)
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET res RESULTSET := (
        SELECT
            p.PARTY_KEY,
            pp.PARTY_NAME,
            p.REVIEW_CYCLE,
            p.NEXT_REVIEW_DATE,
            DATEDIFF(DAY, p.NEXT_REVIEW_DATE, CURRENT_DATE()) AS DAYS_OVERDUE,
            COALESCE(r.CURRENT_RATING, 'UNRATED') AS CURRENT_RISK
        FROM GENERIC_DB.COMPLIANCE.PDD_SCHEDULE p
        JOIN GENERIC_DB.PARTY_MART.PARTY_PROFILE_CURRENT pp
            ON pp.PARTY_PROFILE_ID = p.PARTY_KEY
        LEFT JOIN GENERIC_DB.COMPLIANCE.RISK_RATINGS r
            ON r.PARTY_KEY = p.PARTY_KEY
        WHERE p.NEXT_REVIEW_DATE < CURRENT_DATE()
        ORDER BY DAYS_OVERDUE DESC
    );
    RETURN TABLE(res);
END;

-- ============================================================================
-- 5.5 SP_UPDATE_RISK_RATING — Update a party's risk rating
-- ============================================================================
-- Changes the risk rating, adjusts PDD schedule, and queues reviews for
-- HIGH/CRITICAL rated parties.

CREATE OR REPLACE PROCEDURE GENERIC_DB.COMPLIANCE.SP_UPDATE_RISK_RATING(
    P_PARTY_KEY VARCHAR,
    P_NEW_RATING VARCHAR,
    P_REASON VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET v_old_rating VARCHAR;
    LET v_new_cycle VARCHAR;

    -- Get current rating
    SELECT CURRENT_RATING INTO :v_old_rating
    FROM GENERIC_DB.COMPLIANCE.RISK_RATINGS
    WHERE PARTY_KEY = :P_PARTY_KEY
    LIMIT 1;

    IF (v_old_rating IS NULL) THEN
        RETURN 'ERROR: No risk rating found for party ' || :P_PARTY_KEY;
    END IF;

    -- Update risk rating
    UPDATE GENERIC_DB.COMPLIANCE.RISK_RATINGS
    SET PREVIOUS_RATING = CURRENT_RATING,
        CURRENT_RATING = :P_NEW_RATING,
        RATING_DATE = CURRENT_DATE(),
        RATING_REASON = :P_REASON
    WHERE PARTY_KEY = :P_PARTY_KEY;

    -- Determine new PDD review cycle based on rating
    CASE
        WHEN UPPER(:P_NEW_RATING) = 'CRITICAL' THEN v_new_cycle := 'QUARTERLY';
        WHEN UPPER(:P_NEW_RATING) = 'HIGH' THEN v_new_cycle := 'SEMI_ANNUAL';
        WHEN UPPER(:P_NEW_RATING) = 'MEDIUM' THEN v_new_cycle := 'ANNUAL';
        ELSE v_new_cycle := 'ANNUAL';
    END CASE;

    -- Update PDD schedule
    UPDATE GENERIC_DB.COMPLIANCE.PDD_SCHEDULE
    SET REVIEW_CYCLE = :v_new_cycle,
        NEXT_REVIEW_DATE = CASE
            WHEN :v_new_cycle = 'QUARTERLY' THEN DATEADD(MONTH, 3, CURRENT_DATE())
            WHEN :v_new_cycle = 'SEMI_ANNUAL' THEN DATEADD(MONTH, 6, CURRENT_DATE())
            ELSE DATEADD(YEAR, 1, CURRENT_DATE())
        END
    WHERE PARTY_KEY = :P_PARTY_KEY;

    -- If HIGH or CRITICAL, add to review queue
    IF (UPPER(:P_NEW_RATING) IN ('HIGH', 'CRITICAL')) THEN
        INSERT INTO GENERIC_DB.COMPLIANCE.REVIEW_QUEUE (
            QUEUE_ID, QUEUE_TYPE, REFERENCE_ID, PARTY_KEY,
            PRIORITY, STATUS, CREATED_AT
        ) VALUES (
            'RQ-' || TO_VARCHAR(UNIFORM(100000, 999999, RANDOM())),
            'RISK_ESCALATION',
            'RISK-' || :P_PARTY_KEY,
            :P_PARTY_KEY,
            CASE WHEN UPPER(:P_NEW_RATING) = 'CRITICAL' THEN 'CRITICAL' ELSE 'HIGH' END,
            'PENDING',
            CURRENT_TIMESTAMP()
        );
    END IF;

    -- Log to audit
    INSERT INTO GENERIC_DB.COMPLIANCE.AUDIT_LOG (
        LOG_ID, ACTION_TYPE, ENTITY_TYPE, ENTITY_ID,
        ACTION_BY, ACTION_TS, DETAILS
    ) VALUES (
        'AUD-' || TO_VARCHAR(UNIFORM(100000, 999999, RANDOM())),
        'RISK_RATING_UPDATED', 'PARTY', :P_PARTY_KEY,
        'CORTEX_AGENT', CURRENT_TIMESTAMP(),
        'Rating changed from ' || :v_old_rating || ' to ' || :P_NEW_RATING || '. Reason: ' || :P_REASON
    );

    RETURN 'Risk rating for ' || :P_PARTY_KEY || ' updated from ' || :v_old_rating || ' to ' || :P_NEW_RATING || '. Reason: ' || :P_REASON || '.';
END;

-- ============================================================================
-- 5.6 SP_PARTY_360 — Consolidated party view as JSON
-- ============================================================================
-- Returns a single JSON object with party profile, contacts, locations,
-- screening history, risk rating, open reviews, and PDD status.

CREATE OR REPLACE PROCEDURE GENERIC_DB.COMPLIANCE.SP_PARTY_360(
    P_PARTY_KEY VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET v_result VARCHAR;

    v_result := (SELECT OBJECT_CONSTRUCT(
        'party_profile', (
            SELECT OBJECT_CONSTRUCT(
                'party_key', pp.PARTY_PROFILE_ID,
                'party_name', pp.PARTY_NAME,
                'legal_form', pp.LEGAL_FORM_CD,
                'jurisdiction', pp.JURISDICTION_CD,
                'country', pp.COUNTRY_CD,
                'created', pp.CREATED_TS
            )
            FROM GENERIC_DB.PARTY_MART.PARTY_PROFILE_CURRENT pp
            WHERE pp.PARTY_PROFILE_ID = :P_PARTY_KEY
        ),
        'contacts', (
            SELECT COALESCE(ARRAY_AGG(
                OBJECT_CONSTRUCT(
                    'contact_id', c.CONTACT_SURROGATE_UUID,
                    'name', c.DISPLAY_NAME,
                    'role', cr.RELATIONSHIP_ROLE_CD,
                    'status', c.STATUS_CODE
                )
            ), ARRAY_CONSTRUCT())
            FROM GENERIC_DB.CONTACT_HUB.CONTACT_RELATIONSHIP_CURRENT cr
            JOIN GENERIC_DB.CONTACT_HUB.CONTACT_RECORD_CURRENT c
                ON c.CONTACT_SURROGATE_UUID = cr.CONTACT_SURROGATE_UUID
            WHERE cr.RELATIONSHIP_ROLE_CD IS NOT NULL
              AND cr.ACTIVE_FLAG = 'Y'
        ),
        'locations', (
            SELECT COALESCE(ARRAY_AGG(
                OBJECT_CONSTRUCT(
                    'type', l.LOCATION_TYPE_DESC,
                    'address', COALESCE(l.DISPLAY_LINE_1, '') || ' ' || COALESCE(l.LOCALITY, ''),
                    'country', l.NATION_CODE,
                    'postal_code', l.POSTAL_CODE
                )
            ), ARRAY_CONSTRUCT())
            FROM GENERIC_DB.PARTY_MART.PARTY_LOCATION_CURRENT l
            WHERE l.PARTY_KEY = :P_PARTY_KEY
        ),
        'screening_history', (
            SELECT COALESCE(ARRAY_AGG(
                OBJECT_CONSTRUCT(
                    'screening_id', s.SCREENING_ID,
                    'date', s.SCREENING_DATE,
                    'match_type', s.MATCH_TYPE,
                    'score', s.MATCH_SCORE,
                    'status', s.STATUS
                )
            ), ARRAY_CONSTRUCT())
            FROM (
                SELECT * FROM GENERIC_DB.COMPLIANCE.SCREENING_RESULTS
                WHERE PARTY_KEY = :P_PARTY_KEY
                ORDER BY SCREENING_DATE DESC
                LIMIT 5
            ) s
        ),
        'risk_rating', (
            SELECT OBJECT_CONSTRUCT(
                'current_rating', r.CURRENT_RATING,
                'previous_rating', r.PREVIOUS_RATING,
                'rating_date', r.RATING_DATE,
                'reason', r.RATING_REASON
            )
            FROM GENERIC_DB.COMPLIANCE.RISK_RATINGS r
            WHERE r.PARTY_KEY = :P_PARTY_KEY
        ),
        'open_reviews', (
            SELECT COALESCE(ARRAY_AGG(
                OBJECT_CONSTRUCT(
                    'review_id', e.REVIEW_ID,
                    'type', e.REVIEW_TYPE,
                    'status', e.STATUS,
                    'due_date', e.DUE_DATE,
                    'trigger', e.TRIGGER_REASON
                )
            ), ARRAY_CONSTRUCT())
            FROM GENERIC_DB.COMPLIANCE.EDD_REVIEWS e
            WHERE e.PARTY_KEY = :P_PARTY_KEY
              AND e.STATUS != 'COMPLETED'
        ),
        'pdd_status', (
            SELECT OBJECT_CONSTRUCT(
                'review_cycle', p.REVIEW_CYCLE,
                'last_review', p.LAST_REVIEW_DATE,
                'next_review', p.NEXT_REVIEW_DATE,
                'is_overdue', IFF(p.NEXT_REVIEW_DATE < CURRENT_DATE(), TRUE, FALSE)
            )
            FROM GENERIC_DB.COMPLIANCE.PDD_SCHEDULE p
            WHERE p.PARTY_KEY = :P_PARTY_KEY
        )
    )::VARCHAR
    FROM TABLE(GENERATOR(ROWCOUNT => 1)));

    RETURN :v_result;
END;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Quick test calls (uncomment after running 01-03):
-- CALL GENERIC_DB.COMPLIANCE.SP_RUN_SCREENING('PTY-001');
-- CALL GENERIC_DB.COMPLIANCE.SP_INITIATE_EDD('PTY-001', 'High-risk jurisdiction');
-- CALL GENERIC_DB.COMPLIANCE.SP_GET_PDD_OVERDUE();
-- CALL GENERIC_DB.COMPLIANCE.SP_PARTY_360('PTY-001');
