/*=============================================================================
  KYC SUPERHERO WORKSHOP - STEP 4: CROSS-REFERENCE & EDD (MAKER)
  ===========================================================================
  The MAKER layer for entity resolution and risk assessment:
  
  Step 6: Cross-reference extracted entities against known data
  - Match applicant names to the heroes database
  - Check against watchlists/sanctions lists
  - Apply fuzzy matching (aliases, partial names)
  
  Step 7: Enhanced Due Diligence (EDD) Assessment
  - AI-powered risk reasoning for flagged entities
  - Generates risk scores, factors, and recommended actions
  ===========================================================================*/

USE ROLE KYC_WORKSHOP_ROLE;
USE DATABASE KYC_SUPERHERO_DB;
USE SCHEMA CURATED;
USE WAREHOUSE KYC_WORKSHOP_WH;

-- ============================================================================
-- 4.1 ENTITY CROSS-REFERENCE VIEW
-- ============================================================================
-- Matches extracted KYC applicants against:
-- 1. Known heroes database (RAW.HEROES)
-- 2. Sanctions/watchlist (RAW.WATCHLIST)
-- 
-- Uses fuzzy matching (ILIKE with wildcards) to catch aliases and variations.
-- In production you'd use Cortex Search or a dedicated entity resolution service.

CREATE OR REPLACE VIEW ENTITY_CROSSREF AS
SELECT
  k.file_name,
  k.extracted_data:response:applicant_name::VARCHAR AS applicant_name,
  k.extracted_data:response:nationality::VARCHAR AS applicant_nationality,
  k.extracted_data:response:occupation::VARCHAR AS applicant_occupation,
  k.extracted_data:response:source_of_funds::VARCHAR AS source_of_funds,
  k.extracted_data:response:politically_exposed::VARCHAR AS declared_pep_status,
  k.extracted_data:response:associated_entities::VARCHAR AS associated_entities,
  
  -- Hero match details
  h.HERO_ID,
  h.HERO_NAME,
  h.REAL_NAME,
  h.ALIAS AS hero_alias,
  h.RISK_LEVEL AS known_risk_level,
  h.AFFILIATION,
  h.STATUS AS hero_status,
  h.NOTES AS hero_notes,
  
  -- Watchlist match details
  w.ENTITY_NAME AS watchlist_entity,
  w.REASON AS watchlist_reason,
  w.RISK_CATEGORY AS watchlist_category,
  w.SOURCE AS watchlist_source,
  
  -- Derived flags
  CASE WHEN h.HERO_ID IS NOT NULL THEN TRUE ELSE FALSE END AS known_entity_match,
  CASE WHEN w.WATCHLIST_ID IS NOT NULL THEN TRUE ELSE FALSE END AS watchlist_match,
  
  -- EDD Required logic (any of these triggers EDD)
  CASE
    WHEN w.WATCHLIST_ID IS NOT NULL AND w.ACTIVE = TRUE THEN TRUE
    WHEN h.RISK_LEVEL IN ('HIGH', 'CRITICAL') THEN TRUE
    WHEN LOWER(k.extracted_data:response:politically_exposed::VARCHAR) ILIKE '%yes%' THEN TRUE
    WHEN k.extracted_data:response:nationality::VARCHAR IN ('Sokovian', 'Asgardian') THEN TRUE
    ELSE FALSE
  END AS edd_required,
  
  -- EDD Trigger reason
  CASE
    WHEN w.WATCHLIST_ID IS NOT NULL AND w.ACTIVE = TRUE 
      THEN 'WATCHLIST_MATCH: ' || w.ENTITY_NAME || ' (' || w.RISK_CATEGORY || ')'
    WHEN h.RISK_LEVEL = 'CRITICAL' 
      THEN 'CRITICAL_RISK_ENTITY'
    WHEN h.RISK_LEVEL = 'HIGH' 
      THEN 'HIGH_RISK_ENTITY'
    WHEN LOWER(k.extracted_data:response:politically_exposed::VARCHAR) ILIKE '%yes%' 
      THEN 'DECLARED_PEP'
    WHEN k.extracted_data:response:nationality::VARCHAR IN ('Sokovian', 'Asgardian') 
      THEN 'HIGH_RISK_JURISDICTION'
    ELSE 'STANDARD_DUE_DILIGENCE'
  END AS edd_trigger_reason

FROM EXTRACTED_KYC k

-- Match against known heroes (fuzzy: name, real name, or alias)
LEFT JOIN KYC_SUPERHERO_DB.RAW.HEROES h
  ON LOWER(k.extracted_data:response:applicant_name::VARCHAR) ILIKE '%' || LOWER(h.REAL_NAME) || '%'
  OR LOWER(k.extracted_data:response:applicant_name::VARCHAR) ILIKE '%' || LOWER(h.HERO_NAME) || '%'
  OR LOWER(h.ALIAS) ILIKE '%' || LOWER(k.extracted_data:response:applicant_name::VARCHAR) || '%'

-- Match against watchlist (check applicant name, associated entities, AND watchlist aliases)
-- Also checks if the matched hero's alias is on the watchlist
LEFT JOIN KYC_SUPERHERO_DB.RAW.WATCHLIST w
  ON (
    -- Direct name match against watchlist entity name
    LOWER(k.extracted_data:response:applicant_name::VARCHAR) ILIKE '%' || LOWER(w.ENTITY_NAME) || '%'
    OR LOWER(w.ENTITY_NAME) ILIKE '%' || LOWER(k.extracted_data:response:applicant_name::VARCHAR) || '%'
    -- Applicant's declared associated entities match watchlist entity
    OR LOWER(COALESCE(k.extracted_data:response:associated_entities::VARCHAR, '')) ILIKE '%' || LOWER(w.ENTITY_NAME) || '%'
    -- Applicant name matches a watchlist alias (MATCH_ALIASES array)
    OR ARRAY_CONTAINS(LOWER(k.extracted_data:response:applicant_name::VARCHAR)::VARIANT, TRANSFORM(w.MATCH_ALIASES, a -> LOWER(a)))
    -- Matched hero name/alias matches watchlist entity or watchlist aliases
    OR (h.HERO_NAME IS NOT NULL AND (
      LOWER(h.HERO_NAME) ILIKE '%' || LOWER(w.ENTITY_NAME) || '%'
      OR LOWER(w.ENTITY_NAME) ILIKE '%' || LOWER(h.HERO_NAME) || '%'
      OR LOWER(COALESCE(h.ALIAS, '')) ILIKE '%' || LOWER(w.ENTITY_NAME) || '%'
      OR ARRAY_CONTAINS(LOWER(h.HERO_NAME)::VARIANT, TRANSFORM(w.MATCH_ALIASES, a -> LOWER(a)))
      OR ARRAY_CONTAINS(LOWER(COALESCE(h.ALIAS, ''))::VARIANT, TRANSFORM(w.MATCH_ALIASES, a -> LOWER(a)))
    ))
  )
  AND w.ACTIVE = TRUE;

-- View all cross-reference results
SELECT 
  file_name,
  applicant_name,
  COALESCE(HERO_NAME, '-- No Match --') AS matched_hero,
  known_risk_level,
  watchlist_match,
  COALESCE(watchlist_entity, '') AS watchlist_entity,
  COALESCE(watchlist_category, '') AS watchlist_category,
  edd_required,
  edd_trigger_reason
FROM ENTITY_CROSSREF
ORDER BY edd_required DESC, applicant_name;


-- ============================================================================
-- 4.2 MAKER: EDD RISK ASSESSMENT
-- ============================================================================
-- For entities flagged for EDD, use AI to perform an initial risk assessment.
-- The AI acts as a "junior analyst" providing a first-pass assessment.

CREATE OR REPLACE TABLE KYC_SUPERHERO_DB.ANALYTICS.EDD_ASSESSMENT AS
SELECT
  x.file_name,
  x.applicant_name,
  x.known_risk_level,
  x.watchlist_match,
  x.watchlist_entity,
  x.watchlist_reason,
  x.watchlist_category,
  x.edd_trigger_reason,
  x.AFFILIATION,
  x.hero_notes,
  x.applicant_occupation,
  x.source_of_funds,
  x.declared_pep_status,
  AI_COMPLETE(
    model => 'claude-sonnet-4-6',
    prompt => CONCAT(
      'You are a KYC analyst conducting an Enhanced Due Diligence (EDD) assessment.\n',
      'Assess the following applicant and provide your risk evaluation.\n\n',
      '=== APPLICANT DETAILS ===\n',
      'Name: ', x.applicant_name, '\n',
      'Occupation: ', COALESCE(x.applicant_occupation, 'Not stated'), '\n',
      'Source of Funds: ', COALESCE(x.source_of_funds, 'Not stated'), '\n',
      'Declared PEP Status: ', COALESCE(x.declared_pep_status, 'Not declared'), '\n',
      'Associated Entities: ', COALESCE(x.associated_entities, 'None stated'), '\n\n',
      '=== SCREENING RESULTS ===\n',
      'Known Entity Match: ', x.known_entity_match::VARCHAR, '\n',
      'Known Risk Level: ', COALESCE(x.known_risk_level, 'UNKNOWN'), '\n',
      'Watchlist Match: ', x.watchlist_match::VARCHAR, '\n',
      'Watchlist Entity: ', COALESCE(x.watchlist_entity, 'N/A'), '\n',
      'Watchlist Reason: ', COALESCE(x.watchlist_reason, 'N/A'), '\n',
      'Watchlist Category: ', COALESCE(x.watchlist_category, 'N/A'), '\n',
      'EDD Trigger: ', x.edd_trigger_reason, '\n',
      'Affiliation: ', COALESCE(x.AFFILIATION, 'Unknown'), '\n',
      'Background Notes: ', COALESCE(x.hero_notes, 'None available'), '\n\n',
      '=== YOUR ASSESSMENT ===\n',
      'Provide:\n',
      '1. A risk score from 1 (lowest) to 10 (highest)\n',
      '2. Key risk factors identified\n',
      '3. Mitigating factors (if any)\n',
      '4. Recommended actions for the compliance team\n',
      '5. A brief summary suitable for a compliance report\n',
      '6. Your recommendation: APPROVE, APPROVE_WITH_CONDITIONS, REJECT, or ESCALATE'
    ),
    response_format => {
      'type': 'json',
      'schema': {
        'type': 'object',
        'properties': {
          'risk_score':       {'type': 'integer'},
          'risk_factors':     {'type': 'array', 'items': {'type': 'string'}},
          'mitigating_factors': {'type': 'array', 'items': {'type': 'string'}},
          'recommended_actions': {'type': 'array', 'items': {'type': 'string'}},
          'summary':          {'type': 'string'},
          'recommendation':   {'type': 'string'}
        },
        'required': ['risk_score', 'risk_factors', 'recommended_actions', 'summary', 'recommendation']
      }
    }
  ) AS edd_assessment,
  CURRENT_TIMESTAMP() AS assessed_at
FROM ENTITY_CROSSREF x
WHERE x.edd_required = TRUE;

-- View EDD assessments
SELECT
  applicant_name,
  known_risk_level,
  watchlist_match,
  edd_trigger_reason,
  edd_assessment:risk_score::INT AS risk_score,
  edd_assessment:recommendation::VARCHAR AS recommendation,
  edd_assessment:summary::VARCHAR AS summary
FROM KYC_SUPERHERO_DB.ANALYTICS.EDD_ASSESSMENT
ORDER BY edd_assessment:risk_score::INT DESC;
