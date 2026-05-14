/*=============================================================================
  COMPLIANCE AGENT WORKSHOP - STEP 4: SEMANTIC VIEWS
  ===========================================================================
  Creates two semantic views in GENERIC_DB.ANALYTICS that enable Cortex
  Analyst / Cortex Agents to query data via natural language:

    1. PARTY_CONTACTS_SV   — Party and contact operational queries
    2. COMPLIANCE_SV        — Risk, screening, EDD, and PDD queries

  Prerequisites: Run 01_setup.sql, 02_seed_data.sql, 03_compliance_tables.sql
  Run as: CPR_WORKSHOP_ROLE
  ===========================================================================*/

-- ============================================================================
-- 4.0 ROLE & WAREHOUSE
-- ============================================================================

USE ROLE CPR_WORKSHOP_ROLE;
USE WAREHOUSE CPR_WORKSHOP_WH;
USE SCHEMA GENERIC_DB.ANALYTICS;

-- ============================================================================
-- 4.1 PARTY_CONTACTS_SV — Party & Contact operational queries
-- ============================================================================
-- Enables natural-language questions about parties, contacts, locations,
-- relationships, jurisdictions, and status distributions.

CREATE OR REPLACE SEMANTIC VIEW GENERIC_DB.ANALYTICS.PARTY_CONTACTS_SV

  TABLES (
    party_master AS GENERIC_DB.PARTY_MART.PARTY_MASTER_CURRENT
      PRIMARY KEY (PARTY_KEY)
      COMMENT = 'Core party master record with status, currency, and lifecycle dates',

    party_profile AS GENERIC_DB.PARTY_MART.PARTY_PROFILE_CURRENT
      PRIMARY KEY (PARTY_PROFILE_ID)
      COMMENT = 'Party profile with name, legal form, jurisdiction, and country',

    party_location AS GENERIC_DB.PARTY_MART.PARTY_LOCATION_CURRENT
      COMMENT = 'Party registered and operating addresses',

    contacts AS GENERIC_DB.CONTACT_HUB.CONTACT_RECORD_CURRENT
      PRIMARY KEY (CONTACT_SURROGATE_UUID)
      COMMENT = 'Individual contact records with name, nationality, and status',

    contact_relationships AS GENERIC_DB.CONTACT_HUB.CONTACT_RELATIONSHIP_CURRENT
      PRIMARY KEY (RELATIONSHIP_ID)
      COMMENT = 'Relationships between contacts and their roles (e.g. director, signatory, UBO)'
  )

  RELATIONSHIPS (
    profile_to_master AS
      party_profile (PARTY_PROFILE_ID) REFERENCES party_master (PARTY_KEY),

    location_to_master AS
      party_location (PARTY_KEY) REFERENCES party_master,

    relationship_to_contact AS
      contact_relationships (CONTACT_SURROGATE_UUID) REFERENCES contacts
  )

  DIMENSIONS (
    -- Party dimensions
    party_profile.PARTY_NAME AS PARTY_NAME
      WITH SYNONYMS = ('name', 'company name', 'entity name', 'client name')
      COMMENT = 'Legal name of the party or entity',

    party_profile.PARTY_PROFILE_ID AS PARTY_PROFILE_ID
      WITH SYNONYMS = ('party id', 'party identifier', 'client id', 'party key')
      COMMENT = 'Unique party identifier in PTY-NNNNNN format',

    party_master.STATUS_CODE AS STATUS_CODE
      WITH SYNONYMS = ('party status', 'account status', 'active status')
      COMMENT = 'Party status code: A=Active, I=Inactive, C=Closed, S=Suspended',

    party_profile.JURISDICTION_CD AS JURISDICTION_CD
      WITH SYNONYMS = ('jurisdiction', 'regulatory jurisdiction', 'registered jurisdiction')
      COMMENT = 'Regulatory jurisdiction where the party is registered',

    party_profile.COUNTRY_CD AS COUNTRY_CD
      WITH SYNONYMS = ('country', 'country code', 'domicile')
      COMMENT = 'Two-letter ISO country code of the party',

    party_profile.LEGAL_FORM_CD AS LEGAL_FORM_CD
      WITH SYNONYMS = ('legal form', 'entity type', 'company type', 'legal structure')
      COMMENT = 'Legal form of the entity (e.g. LLC, PLC, GmbH, AG, KK)',

    party_master.BASE_CURRENCY_CD AS BASE_CURRENCY_CD
      WITH SYNONYMS = ('currency', 'base currency')
      COMMENT = 'Base operating currency of the party',

    party_location.location_country AS NATION_CODE
      WITH SYNONYMS = ('location country', 'address country', 'office country')
      COMMENT = 'Country code of the party location or registered address',

    party_location.LOCALITY AS LOCALITY
      WITH SYNONYMS = ('city', 'town', 'location')
      COMMENT = 'City or locality of the party address',

    party_location.REGION_CODE AS REGION_CODE
      WITH SYNONYMS = ('region', 'state', 'province')
      COMMENT = 'Region or state code of the party address',

    -- Contact dimensions
    contacts.contact_display_name AS DISPLAY_NAME
      WITH SYNONYMS = ('contact name', 'person name', 'individual name')
      COMMENT = 'Full display name of the contact individual',

    contacts.contact_nationality AS NATION_CODE
      WITH SYNONYMS = ('nationality', 'contact country', 'citizenship')
      COMMENT = 'Nationality or country code of the contact',

    contacts.contact_status AS STATUS_CODE
      WITH SYNONYMS = ('contact status')
      COMMENT = 'Contact status: A=Active, I=Inactive',

    contact_relationships.relationship_type AS RELATIONSHIP_TYPE_CD
      WITH SYNONYMS = ('role', 'contact role', 'relationship', 'position')
      COMMENT = 'Type of relationship (e.g. DIRECTOR, UBO, SIGNATORY, SHAREHOLDER)',

    contact_relationships.relationship_role AS RELATIONSHIP_ROLE_CD
      WITH SYNONYMS = ('role code', 'function')
      COMMENT = 'Specific role code within the relationship',

    contact_relationships.relationship_active AS ACTIVE_FLAG
      WITH SYNONYMS = ('active relationship', 'current relationship')
      COMMENT = 'Whether the contact relationship is currently active (Y/N)'
  )

  METRICS (
    party_master.party_count AS COUNT(PARTY_KEY)
      WITH SYNONYMS = ('number of parties', 'total parties', 'how many parties', 'entity count')
      COMMENT = 'Total count of parties',

    contacts.contact_count AS COUNT(CONTACT_SURROGATE_UUID)
      WITH SYNONYMS = ('number of contacts', 'total contacts', 'how many contacts')
      COMMENT = 'Total count of contact records',

    contact_relationships.relationship_count AS COUNT(RELATIONSHIP_ID)
      WITH SYNONYMS = ('number of relationships', 'total relationships')
      COMMENT = 'Total count of contact-to-party relationships'
  )

  COMMENT = 'Semantic view for querying party master data, contacts, locations, and relationships. Use for operational questions about clients, their contacts, jurisdictions, and status.';

-- ============================================================================
-- 4.2 COMPLIANCE_SV — Risk, screening, EDD, PDD, and queue queries
-- ============================================================================
-- Enables natural-language questions about risk ratings, screening results,
-- enhanced due diligence reviews, periodic reviews, and the analyst queue.

CREATE OR REPLACE SEMANTIC VIEW GENERIC_DB.ANALYTICS.COMPLIANCE_SV

  TABLES (
    party_profile AS GENERIC_DB.PARTY_MART.PARTY_PROFILE_CURRENT
      PRIMARY KEY (PARTY_PROFILE_ID)
      COMMENT = 'Party profile providing name and jurisdiction context for compliance data',

    risk_ratings AS GENERIC_DB.COMPLIANCE.RISK_RATINGS
      PRIMARY KEY (RATING_ID)
      UNIQUE (PARTY_KEY)
      COMMENT = 'Current and previous risk rating per party with justification',

    screening AS GENERIC_DB.COMPLIANCE.SCREENING_RESULTS
      PRIMARY KEY (SCREENING_ID)
      COMMENT = 'Watchlist and sanctions screening results with match scores',

    edd_reviews AS GENERIC_DB.COMPLIANCE.EDD_REVIEWS
      PRIMARY KEY (REVIEW_ID)
      COMMENT = 'Enhanced Due Diligence review records with findings and recommendations',

    pdd_schedule AS GENERIC_DB.COMPLIANCE.PDD_SCHEDULE
      PRIMARY KEY (PDD_ID)
      COMMENT = 'Periodic Due Diligence schedule tracking review cycles and due dates',

    review_queue AS GENERIC_DB.COMPLIANCE.REVIEW_QUEUE
      PRIMARY KEY (QUEUE_ID)
      COMMENT = 'Work queue of items awaiting analyst action with priority and status'
  )

  RELATIONSHIPS (
    risk_to_party AS
      risk_ratings (PARTY_KEY) REFERENCES party_profile (PARTY_PROFILE_ID),

    screening_to_party AS
      screening (PARTY_KEY) REFERENCES party_profile (PARTY_PROFILE_ID),

    edd_to_party AS
      edd_reviews (PARTY_KEY) REFERENCES party_profile (PARTY_PROFILE_ID),

    pdd_to_party AS
      pdd_schedule (PARTY_KEY) REFERENCES party_profile (PARTY_PROFILE_ID),

    queue_to_party AS
      review_queue (PARTY_KEY) REFERENCES party_profile (PARTY_PROFILE_ID)
  )

  FACTS (
    screening.match_score AS MATCH_SCORE
      WITH SYNONYMS = ('screening score', 'match confidence', 'hit score')
      COMMENT = 'Numeric match confidence score from screening (0-100)',

    edd_reviews.edd_risk_score AS RISK_SCORE
      WITH SYNONYMS = ('EDD risk score', 'review risk score')
      COMMENT = 'Risk score assigned during EDD review (1-10)'
  )

  DIMENSIONS (
    -- Party context
    party_profile.party_name AS PARTY_NAME
      WITH SYNONYMS = ('name', 'entity name', 'client name', 'company')
      COMMENT = 'Legal name of the party',

    party_profile.PARTY_PROFILE_ID AS PARTY_PROFILE_ID
      WITH SYNONYMS = ('party id', 'party key', 'client id')
      COMMENT = 'Unique party identifier in PTY-NNNNNN format',

    party_profile.jurisdiction_cd AS JURISDICTION_CD
      WITH SYNONYMS = ('jurisdiction')
      COMMENT = 'Regulatory jurisdiction of the party',

    party_profile.country_cd AS COUNTRY_CD
      WITH SYNONYMS = ('country')
      COMMENT = 'Country code of the party',

    -- Risk rating dimensions
    risk_ratings.current_risk_rating AS CURRENT_RATING
      WITH SYNONYMS = ('risk rating', 'risk level', 'current risk', 'risk category')
      COMMENT = 'Current risk rating: LOW, MEDIUM, HIGH, or CRITICAL',

    risk_ratings.previous_risk_rating AS PREVIOUS_RATING
      WITH SYNONYMS = ('old rating', 'prior rating', 'previous risk')
      COMMENT = 'Previous risk rating before the last change',

    risk_ratings.rating_date AS rating_date
      WITH SYNONYMS = ('when was risk rated', 'rating date')
      COMMENT = 'Date the current risk rating was assigned',

    risk_ratings.rated_by AS rated_by
      WITH SYNONYMS = ('who rated', 'risk analyst')
      COMMENT = 'Analyst who assigned the current risk rating',

    risk_ratings.rating_reason AS rating_reason
      WITH SYNONYMS = ('risk reason', 'why this rating', 'rating justification')
      COMMENT = 'Justification for the current risk rating',

    -- Screening dimensions
    screening.screening_id AS screening_id
      COMMENT = 'Unique screening result identifier',

    screening.screening_match_type AS MATCH_TYPE
      WITH SYNONYMS = ('match result', 'screening result', 'hit type')
      COMMENT = 'Screening match type: EXACT, FUZZY, PARTIAL, or NO_MATCH',

    screening.matched_list AS matched_list
      WITH SYNONYMS = ('watchlist', 'sanctions list', 'list name')
      COMMENT = 'Name of matched watchlist: OFAC, EU_SANCTIONS, HMT, UN_SCL, PEP_LIST, INTERNAL',

    screening.screening_risk_category AS RISK_CATEGORY
      WITH SYNONYMS = ('screening risk', 'threat category')
      COMMENT = 'Risk category of the match: TERRORISM, MONEY_LAUNDERING, SANCTIONS, PEP, PROLIFERATION',

    screening.screening_status AS STATUS
      WITH SYNONYMS = ('screening status', 'screening outcome')
      COMMENT = 'Status of the screening: COMPLETED, OPEN, CLEARED, CONFIRMED, ESCALATED',

    screening.screened_by AS screened_by
      COMMENT = 'Analyst who performed the screening',

    screening.screening_date AS screening_date
      WITH SYNONYMS = ('when screened', 'screening date', 'screen date')
      COMMENT = 'Date and time the screening was performed',

    -- EDD dimensions
    edd_reviews.edd_review_id AS REVIEW_ID
      WITH SYNONYMS = ('EDD id', 'review identifier')
      COMMENT = 'Unique Enhanced Due Diligence review identifier',

    edd_reviews.edd_trigger_reason AS TRIGGER_REASON
      WITH SYNONYMS = ('EDD reason', 'why EDD', 'trigger', 'EDD trigger')
      COMMENT = 'Reason EDD was triggered: WATCHLIST_MATCH, HIGH_RISK_JURISDICTION, PEP, COMPLEX_STRUCTURE, UNUSUAL_ACTIVITY, PERIODIC',

    edd_reviews.edd_status AS STATUS
      WITH SYNONYMS = ('EDD status', 'review status', 'EDD state')
      COMMENT = 'EDD review status: PENDING, IN_PROGRESS, COMPLETED, OVERDUE',

    edd_reviews.edd_recommendation AS RECOMMENDATION
      WITH SYNONYMS = ('EDD decision', 'review decision', 'EDD outcome')
      COMMENT = 'EDD recommendation: APPROVE, REJECT, ESCALATE, MONITOR',

    edd_reviews.edd_assigned_to AS ASSIGNED_TO
      WITH SYNONYMS = ('EDD analyst', 'assigned analyst', 'who is reviewing')
      COMMENT = 'Analyst assigned to the EDD review',

    edd_reviews.edd_due_date AS DUE_DATE
      WITH SYNONYMS = ('EDD due date', 'review deadline')
      COMMENT = 'Due date for EDD review completion',

    -- PDD dimensions
    pdd_schedule.pdd_review_cycle AS REVIEW_CYCLE
      WITH SYNONYMS = ('review frequency', 'PDD cycle', 'review cycle')
      COMMENT = 'Periodic review frequency: ANNUAL, SEMI_ANNUAL, QUARTERLY',

    pdd_schedule.pdd_status AS STATUS
      WITH SYNONYMS = ('PDD status', 'periodic review status')
      COMMENT = 'PDD status: ON_TRACK, DUE_SOON, OVERDUE, COMPLETED',

    pdd_schedule.pdd_risk_tier AS RISK_TIER
      WITH SYNONYMS = ('PDD risk tier', 'review risk tier')
      COMMENT = 'Risk tier driving the PDD schedule: LOW, MEDIUM, HIGH, CRITICAL',

    pdd_schedule.pdd_next_review_date AS NEXT_REVIEW_DATE
      WITH SYNONYMS = ('next PDD', 'next review', 'next periodic review')
      COMMENT = 'Date of the next scheduled periodic review',

    pdd_schedule.pdd_last_review_date AS LAST_REVIEW_DATE
      WITH SYNONYMS = ('last PDD', 'last review', 'last periodic review')
      COMMENT = 'Date of the most recent completed periodic review',

    pdd_schedule.pdd_assigned_to AS ASSIGNED_TO
      COMMENT = 'Analyst assigned to the periodic review',

    -- Review queue dimensions
    review_queue.queue_type AS queue_type
      WITH SYNONYMS = ('queue category', 'work type', 'item type')
      COMMENT = 'Type of queued item: SCREENING, EDD, PDD, RISK_ESCALATION, ESCALATION',

    review_queue.queue_priority AS PRIORITY
      WITH SYNONYMS = ('priority', 'urgency', 'importance')
      COMMENT = 'Priority of the queue item: LOW, MEDIUM, HIGH, CRITICAL',

    review_queue.queue_status AS STATUS
      WITH SYNONYMS = ('queue status', 'work status', 'item status')
      COMMENT = 'Status of the queue item: PENDING, ASSIGNED, IN_PROGRESS, COMPLETED',

    review_queue.queue_assigned_to AS ASSIGNED_TO
      WITH SYNONYMS = ('queue analyst', 'assigned to')
      COMMENT = 'Analyst assigned to the queue item'
  )

  METRICS (
    -- Risk rating metrics
    risk_ratings.high_risk_party_count AS COUNT_IF(CURRENT_RATING IN ('HIGH', 'CRITICAL'))
      WITH SYNONYMS = ('high risk count', 'number of high risk parties', 'risky parties')
      COMMENT = 'Count of parties rated HIGH or CRITICAL',

    risk_ratings.critical_party_count AS COUNT_IF(CURRENT_RATING = 'CRITICAL')
      WITH SYNONYMS = ('critical count', 'number of critical parties')
      COMMENT = 'Count of parties with CRITICAL risk rating',

    risk_ratings.total_rated_parties AS COUNT(RATING_ID)
      WITH SYNONYMS = ('rated party count', 'total rated')
      COMMENT = 'Total number of parties with a risk rating',

    -- Screening metrics
    screening.total_screenings AS COUNT(SCREENING_ID)
      WITH SYNONYMS = ('screening count', 'number of screenings', 'how many screenings')
      COMMENT = 'Total count of screening records',

    screening.screening_hit_count AS COUNT_IF(MATCH_TYPE IN ('EXACT', 'FUZZY', 'PARTIAL'))
      WITH SYNONYMS = ('hits', 'matches', 'screening matches', 'positive screenings')
      COMMENT = 'Count of screenings with a match (EXACT, FUZZY, or PARTIAL)',

    screening.confirmed_hit_count AS COUNT_IF(STATUS = 'CONFIRMED')
      WITH SYNONYMS = ('confirmed matches', 'true positives', 'confirmed screenings')
      COMMENT = 'Count of confirmed screening hits',

    screening.avg_match_score AS AVG(MATCH_SCORE)
      WITH SYNONYMS = ('average score', 'mean match score')
      COMMENT = 'Average match score across all screenings',

    -- EDD metrics
    edd_reviews.total_edd_reviews AS COUNT(REVIEW_ID)
      WITH SYNONYMS = ('EDD count', 'number of EDD reviews', 'total reviews')
      COMMENT = 'Total count of EDD review records',

    edd_reviews.open_edd_count AS COUNT_IF(STATUS IN ('PENDING', 'IN_PROGRESS', 'OVERDUE'))
      WITH SYNONYMS = ('open reviews', 'active EDD', 'pending EDD', 'incomplete EDD')
      COMMENT = 'Count of EDD reviews not yet completed',

    edd_reviews.overdue_edd_count AS COUNT_IF(STATUS = 'OVERDUE')
      WITH SYNONYMS = ('overdue EDD', 'late reviews', 'overdue reviews')
      COMMENT = 'Count of EDD reviews past their due date',

    edd_reviews.avg_risk_score AS AVG(RISK_SCORE)
      WITH SYNONYMS = ('average EDD risk', 'mean risk score')
      COMMENT = 'Average risk score across EDD reviews',

    -- PDD metrics
    pdd_schedule.total_pdd_entries AS COUNT(PDD_ID)
      WITH SYNONYMS = ('PDD count', 'periodic review count')
      COMMENT = 'Total count of PDD schedule entries',

    pdd_schedule.overdue_pdd_count AS COUNT_IF(STATUS = 'OVERDUE')
      WITH SYNONYMS = ('overdue PDD', 'overdue periodic reviews', 'late PDD')
      COMMENT = 'Count of periodic reviews that are overdue',

    pdd_schedule.due_soon_pdd_count AS COUNT_IF(STATUS = 'DUE_SOON')
      WITH SYNONYMS = ('upcoming PDD', 'PDD due soon')
      COMMENT = 'Count of periodic reviews coming due soon',

    -- Queue metrics
    review_queue.queue_depth AS COUNT(QUEUE_ID)
      WITH SYNONYMS = ('queue size', 'queue count', 'backlog', 'work items', 'items in queue')
      COMMENT = 'Total number of items in the review queue',

    review_queue.pending_queue_items AS COUNT_IF(STATUS = 'PENDING')
      WITH SYNONYMS = ('unassigned items', 'pending work', 'awaiting assignment')
      COMMENT = 'Count of queue items still pending assignment',

    review_queue.urgent_queue_items AS COUNT_IF(PRIORITY IN ('HIGH', 'CRITICAL'))
      WITH SYNONYMS = ('urgent items', 'high priority items', 'critical items')
      COMMENT = 'Count of HIGH or CRITICAL priority items in the queue'
  )

  COMMENT = 'Semantic view for compliance analytics: risk ratings, screening results, EDD reviews, PDD schedules, and analyst work queue. Use for risk distribution, screening hit rates, overdue reviews, and queue management questions.';

-- ============================================================================
-- 4.3 VERIFICATION
-- ============================================================================

-- Confirm semantic views exist
SHOW SEMANTIC VIEWS IN SCHEMA GENERIC_DB.ANALYTICS;

-- Check dimensions and metrics for each view
SHOW SEMANTIC DIMENSIONS IN GENERIC_DB.ANALYTICS.PARTY_CONTACTS_SV;
SHOW SEMANTIC METRICS IN GENERIC_DB.ANALYTICS.PARTY_CONTACTS_SV;
SHOW SEMANTIC DIMENSIONS IN GENERIC_DB.ANALYTICS.COMPLIANCE_SV;
SHOW SEMANTIC FACTS IN GENERIC_DB.ANALYTICS.COMPLIANCE_SV;
SHOW SEMANTIC METRICS IN GENERIC_DB.ANALYTICS.COMPLIANCE_SV;

SELECT 'Semantic views created! Run 05_stored_procedures.sql next.' AS STATUS;
