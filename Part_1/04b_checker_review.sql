/*=============================================================================
  KYC SUPERHERO WORKSHOP - STEP 4B: CROSS-REF & EDD CHECKER
  ===========================================================================
  The CHECKER layer for entity resolution and EDD assessment.
  
  Step 6C: Validate entity cross-reference quality
  - Are the matches genuine (not false positives)?
  - Are there missed matches (false negatives)?
  - Is the EDD trigger decision appropriate?
  
  Step 7C: Senior compliance review of EDD assessments
  - An independent "senior officer" AI challenges the maker's assessment
  - Compares risk scores for variance
  - Checks regulatory completeness
  - Provides APPROVED / REJECTED / ESCALATE decision
  ===========================================================================*/

USE ROLE KYC_WORKSHOP_ROLE;
USE DATABASE KYC_SUPERHERO_DB;
USE SCHEMA CURATED;
USE WAREHOUSE KYC_WORKSHOP_WH;

-- ============================================================================
-- 4B.1 CHECKER: VALIDATE ENTITY CROSS-REFERENCE
-- ============================================================================
-- The checker validates that:
-- 1. Positive matches are genuine (not false positives from fuzzy matching)
-- 2. No obvious matches were missed (false negatives)
-- 3. The EDD trigger decision is appropriate

CREATE OR REPLACE TABLE CHECKED_CROSSREF AS
SELECT
  x.file_name,
  x.applicant_name,
  x.HERO_NAME,
  x.REAL_NAME,
  x.known_risk_level,
  x.watchlist_match,
  x.watchlist_entity,
  x.watchlist_reason,
  x.edd_required,
  x.edd_trigger_reason,
  AI_COMPLETE(
    model => 'claude-sonnet-4-6',
    prompt => CONCAT(
      'You are a SENIOR KYC ANALYST validating entity matching results.\n',
      'Your job is to check whether the automated name-screening produced correct results.\n\n',
      '=== MATCHING RESULT TO VALIDATE ===\n',
      'Applicant Name (from KYC form): "', x.applicant_name, '"\n',
      'Matched to Known Entity: "', COALESCE(x.HERO_NAME, 'NO MATCH'), '"',
      CASE WHEN x.REAL_NAME IS NOT NULL THEN ' (Real name: "' || x.REAL_NAME || '")' ELSE '' END, '\n',
      'Match Confidence: ', CASE WHEN x.HERO_ID IS NOT NULL THEN 'POSITIVE' ELSE 'NO MATCH' END, '\n',
      'Watchlist Match: ', x.watchlist_match::VARCHAR, '\n',
      'Watchlist Entity: "', COALESCE(x.watchlist_entity, 'N/A'), '"\n',
      'EDD Required (system decision): ', x.edd_required::VARCHAR, '\n',
      'EDD Trigger Reason: ', x.edd_trigger_reason, '\n\n',
      '=== KNOWN ALIASES IN OUR DATABASE ===\n',
      '(Use these to check for false negatives)\n',
      '- Tony Stark = Iron Man = "Merchant of Death"\n',
      '- Steve Rogers = Captain America = "The First Avenger"\n',
      '- Natasha Romanoff = Black Widow = Natalia Alianovna Romanova\n',
      '- Bruce Banner = Hulk = "The Green Goliath" = "Joe Fixit"\n',
      '- Thor Odinson = "God of Thunder"\n',
      '- Peter Parker = Spider-Man = "The Web-Slinger"\n',
      '- T''Challa = Black Panther = "King of Wakanda"\n',
      '- Wanda Maximoff = Scarlet Witch\n',
      '- Stephen Strange = Doctor Strange = "Sorcerer Supreme"\n',
      '- Clint Barton = Hawkeye = "The Marksman"\n\n',
      '=== YOUR VALIDATION TASKS ===\n',
      '1. Is the hero match CORRECT? (Could the applicant name genuinely be this person?)\n',
      '2. Is the watchlist match GENUINE? (Or is it a coincidental/partial string match?)\n',
      '3. Are there MISSED matches? (Could this applicant be someone else in our database?)\n',
      '4. Is the EDD decision APPROPRIATE? Should it be upgraded, downgraded, or kept?\n',
      '5. Rate your confidence in the overall screening result.\n\n',
      'Remember: A false negative (missed match) is far more dangerous than a false positive.'
    ),
    response_format => {
      'type': 'json',
      'schema': {
        'type': 'object',
        'properties': {
          'check_status':           {'type': 'string'},
          'confidence_score':       {'type': 'integer'},
          'hero_match_valid':       {'type': 'boolean'},
          'watchlist_match_valid':  {'type': 'boolean'},
          'potential_missed_matches': {'type': 'array', 'items': {'type': 'string'}},
          'edd_decision_appropriate': {'type': 'boolean'},
          'recommended_action':     {'type': 'string'},
          'false_positive_risk':    {'type': 'string'},
          'false_negative_risk':    {'type': 'string'},
          'checker_notes':          {'type': 'string'}
        },
        'required': ['check_status', 'confidence_score', 'hero_match_valid', 
                     'watchlist_match_valid', 'edd_decision_appropriate', 'checker_notes']
      }
    }
  ) AS checker_output,
  CURRENT_TIMESTAMP() AS checked_at
FROM ENTITY_CROSSREF x;

-- View cross-reference checker results
SELECT
  file_name,
  applicant_name,
  COALESCE(HERO_NAME, '-- No Match --') AS matched_hero,
  checker_output:check_status::VARCHAR AS check_status,
  checker_output:confidence_score::INT AS confidence,
  checker_output:hero_match_valid::BOOLEAN AS match_valid,
  checker_output:edd_decision_appropriate::BOOLEAN AS edd_appropriate,
  checker_output:recommended_action::VARCHAR AS recommendation,
  checker_output:false_positive_risk::VARCHAR AS fp_risk,
  checker_output:false_negative_risk::VARCHAR AS fn_risk,
  checker_output:potential_missed_matches AS missed_matches,
  checker_output:checker_notes::VARCHAR AS notes
FROM CHECKED_CROSSREF
ORDER BY checker_output:confidence_score::INT ASC;


-- ============================================================================
-- 4B.2 CHECKER: SENIOR COMPLIANCE REVIEW OF EDD ASSESSMENTS
-- ============================================================================
-- This is the "second line of defence" - a senior officer reviews the
-- maker's EDD assessment with a challenger mindset.
-- 
-- In a real bank this would be a senior compliance officer or team lead
-- reviewing a junior analyst's work before it goes to committee.

CREATE OR REPLACE TABLE KYC_SUPERHERO_DB.ANALYTICS.CHECKED_EDD AS
SELECT
  e.file_name,
  e.applicant_name,
  e.known_risk_level,
  e.watchlist_match,
  e.watchlist_reason,
  e.watchlist_category,
  e.edd_trigger_reason,
  e.edd_assessment AS maker_assessment,
  AI_COMPLETE(
    model => 'claude-sonnet-4-6',
    prompt => CONCAT(
      'You are a SENIOR COMPLIANCE OFFICER performing a SECOND-LINE REVIEW.\n',
      'Your role is to CHALLENGE the initial assessment, not rubber-stamp it.\n',
      'You report to the Head of Financial Crime and must ensure regulatory standards.\n\n',
      '=== APPLICANT ===\n',
      'Name: ', e.applicant_name, '\n',
      'Risk Level: ', COALESCE(e.known_risk_level, 'UNKNOWN'), '\n',
      'Watchlist Match: ', e.watchlist_match::VARCHAR, '\n',
      'Watchlist Category: ', COALESCE(e.watchlist_category, 'N/A'), '\n',
      'Watchlist Reason: ', COALESCE(e.watchlist_reason, 'N/A'), '\n',
      'EDD Trigger: ', e.edd_trigger_reason, '\n',
      'Occupation: ', COALESCE(e.applicant_occupation, 'Not stated'), '\n',
      'Source of Funds: ', COALESCE(e.source_of_funds, 'Not stated'), '\n',
      'PEP Status: ', COALESCE(e.declared_pep_status, 'Not declared'), '\n\n',
      '=== INITIAL (MAKER) EDD ASSESSMENT ===\n',
      e.edd_assessment::VARCHAR, '\n\n',
      '=== YOUR SENIOR REVIEW ===\n',
      'As the reviewing officer, evaluate:\n',
      '1. RISK SCORE: Is it appropriate? (Too lenient? Too harsh? Provide your own score)\n',
      '2. RISK FACTORS: Are all relevant factors identified? What''s missing?\n',
      '3. MITIGANTS: Are claimed mitigating factors legitimate?\n',
      '4. ACTIONS: Are recommended actions proportionate and complete?\n',
      '5. REGULATORY: Does this meet FCA/PRA expectations for EDD?\n',
      '   - Is source of wealth adequately investigated?\n',
      '   - Is ongoing monitoring proposed?\n',
      '   - Are reporting obligations (SAR/STR) considered?\n',
      '6. DECISION: APPROVED / REJECTED / ESCALATE_TO_MLRO'
    ),
    response_format => {
      'type': 'json',
      'schema': {
        'type': 'object',
        'properties': {
          'check_status':               {'type': 'string'},
          'senior_risk_score':          {'type': 'integer'},
          'maker_risk_score_appropriate': {'type': 'boolean'},
          'score_variance':             {'type': 'integer'},
          'missing_risk_factors':       {'type': 'array', 'items': {'type': 'string'}},
          'additional_actions_required': {'type': 'array', 'items': {'type': 'string'}},
          'regulatory_compliance':      {'type': 'string'},
          'sar_consideration':          {'type': 'boolean'},
          'ongoing_monitoring_level':   {'type': 'string'},
          'escalation_reason':          {'type': 'string'},
          'final_recommendation':       {'type': 'string'},
          'checker_notes':              {'type': 'string'}
        },
        'required': ['check_status', 'senior_risk_score', 'maker_risk_score_appropriate',
                     'regulatory_compliance', 'final_recommendation']
      }
    }
  ) AS senior_review,
  CURRENT_TIMESTAMP() AS reviewed_at
FROM KYC_SUPERHERO_DB.ANALYTICS.EDD_ASSESSMENT e;

-- View senior review results
SELECT
  applicant_name,
  known_risk_level,
  edd_trigger_reason,
  senior_review:check_status::VARCHAR AS senior_decision,
  senior_review:senior_risk_score::INT AS senior_risk_score,
  senior_review:maker_risk_score_appropriate::BOOLEAN AS maker_score_ok,
  senior_review:score_variance::INT AS score_variance,
  senior_review:regulatory_compliance::VARCHAR AS reg_compliance,
  senior_review:sar_consideration::BOOLEAN AS sar_needed,
  senior_review:ongoing_monitoring_level::VARCHAR AS monitoring_level,
  senior_review:final_recommendation::VARCHAR AS recommendation
FROM KYC_SUPERHERO_DB.ANALYTICS.CHECKED_EDD
ORDER BY senior_review:senior_risk_score::INT DESC;

-- Show where senior officer disagreed with initial assessment
SELECT
  applicant_name,
  senior_review:senior_risk_score::INT AS senior_score,
  senior_review:score_variance::INT AS variance,
  senior_review:check_status::VARCHAR AS decision,
  senior_review:missing_risk_factors AS missing_factors,
  senior_review:additional_actions_required AS extra_actions,
  senior_review:escalation_reason::VARCHAR AS escalation_reason
FROM KYC_SUPERHERO_DB.ANALYTICS.CHECKED_EDD
WHERE senior_review:maker_risk_score_appropriate::BOOLEAN = FALSE
   OR senior_review:check_status::VARCHAR != 'APPROVED'
ORDER BY ABS(senior_review:score_variance::INT) DESC;
