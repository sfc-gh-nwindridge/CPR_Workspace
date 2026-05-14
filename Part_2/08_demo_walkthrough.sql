/*=============================================================================
  PART 2 - STEP 8: DEMO WALKTHROUGH — Talk To Your Data with Cortex Agent
  ===========================================================================
  This script demonstrates the Compliance Agent's capabilities.
  
  HOW TO USE:
    Option A: Open the Agent in Snowsight UI
      → Navigate to AI & ML > Cortex Agents > COMPLIANCE_AGENT
      → Type the suggested questions directly into the chat interface
    
    Option B: Use the SQL function SNOWFLAKE.CORTEX.DATA_AGENT_RUN() shown below
      → Run each query in a Snowsight worksheet
  
  Prerequisites: Run scripts 01-07 first.
  Run as: CPR_WORKSHOP_ROLE
  ===========================================================================*/

-- ============================================================================
-- SETUP
-- ============================================================================

USE ROLE CPR_WORKSHOP_ROLE;
USE DATABASE GENERIC_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE CPR_WORKSHOP_WH;

-- ============================================================================
-- DEMO 1: NATURAL LANGUAGE QUERIES (Cortex Analyst via Semantic Views)
-- ============================================================================
-- The agent translates natural language into SQL using the semantic views
-- PARTY_CONTACTS_SV and COMPLIANCE_SV. No SQL knowledge required.
-- ============================================================================

-- Q: "How many parties do we have by jurisdiction?"
-- Try in Snowsight Agent UI, or run:
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "How many parties do we have by jurisdiction?"}]}], "stream": false }$$
);

-- Verify: the agent should produce something equivalent to:
SELECT pp.JURISDICTION_CD, COUNT(DISTINCT pm.PARTY_KEY) AS PARTY_COUNT
FROM GENERIC_DB.PARTY_MART.PARTY_MASTER_CURRENT pm
JOIN GENERIC_DB.PARTY_MART.PARTY_PROFILE_CURRENT pp
  ON pm.PARTY_KEY = pp.PARTY_PROFILE_ID
GROUP BY pp.JURISDICTION_CD
ORDER BY PARTY_COUNT DESC;

-- ............................................................................

-- Q: "Show me all HIGH and CRITICAL risk parties"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Show me all HIGH and CRITICAL risk parties"}]}]}$$
);

-- Verify:
SELECT rr.PARTY_KEY, pp.PARTY_NAME, rr.CURRENT_RATING, rr.RATING_DATE
FROM GENERIC_DB.COMPLIANCE.RISK_RATINGS rr
JOIN GENERIC_DB.PARTY_MART.PARTY_PROFILE_CURRENT pp
  ON rr.PARTY_KEY = pp.PARTY_PROFILE_ID
WHERE rr.CURRENT_RATING IN ('HIGH', 'CRITICAL')
ORDER BY rr.CURRENT_RATING, pp.PARTY_NAME;

-- ............................................................................

-- Q: "Which parties in Singapore have more than 3 contacts?"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Which parties in Singapore have more than 3 contacts?"}]}]}$$
);

-- ............................................................................

-- Q: "What is the screening hit rate this quarter?"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What is the screening hit rate this quarter?"}]}]}$$
);


-- ============================================================================
-- DEMO 2: COMPLIANCE WORKFLOWS (Stored Procedure Tools)
-- ============================================================================
-- The agent invokes deterministic stored procedures to take actions.
-- Each action is logged to the audit trail automatically.
-- ============================================================================

-- Q: "Run screening on PTY-000003"
-- The agent calls SP_RUN_SCREENING and returns the match summary.
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Run screening on PTY-000003"}]}]}$$
);

-- Verify: check screening results were logged
SELECT * FROM GENERIC_DB.COMPLIANCE.SCREENING_RESULTS
WHERE PARTY_KEY = 'PTY-000003'
ORDER BY SCREENING_DATE DESC
LIMIT 5;

-- ............................................................................

-- Q: "Show me all overdue PDD reviews"
-- The agent calls SP_GET_PDD_OVERDUE to find parties past their review date.
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Show me all overdue PDD reviews"}]}]}$$
);

-- Verify:
SELECT * FROM GENERIC_DB.COMPLIANCE.PDD_SCHEDULE
WHERE NEXT_REVIEW_DATE < CURRENT_DATE()
  AND STATUS = 'ACTIVE'
ORDER BY NEXT_REVIEW_DATE;

-- ............................................................................

-- Q: "Initiate an EDD review for PTY-000015 - trigger: complex corporate structure"
-- The agent calls SP_INITIATE_EDD and returns a new case ID.
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Initiate an EDD review for PTY-000015 - trigger: complex corporate structure"}]}]}$$
);

-- Verify: check the new EDD review was created
SELECT * FROM GENERIC_DB.COMPLIANCE.EDD_REVIEWS
WHERE PARTY_KEY = 'PTY-000015'
ORDER BY INITIATED_AT DESC
LIMIT 1;

-- ............................................................................

-- Q: "Update the risk rating for PTY-000042 to HIGH because of new adverse media"
-- The agent calls SP_UPDATE_RISK_RATING with full audit trail.
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Update the risk rating for PTY-000042 to HIGH because of new adverse media"}]}]}$$
);

-- Verify: check the audit log
SELECT * FROM GENERIC_DB.COMPLIANCE.AUDIT_LOG
WHERE PARTY_KEY = 'PTY-000042'
ORDER BY ACTION_TS DESC
LIMIT 5;


-- ============================================================================
-- DEMO 3: UNSTRUCTURED SEARCH (Cortex Search)
-- ============================================================================
-- The agent searches free-text compliance notes, analyst memos, and
-- SAR summaries using the COMPLIANCE_SEARCH Cortex Search Service.
-- ============================================================================

-- Q: "What compliance notes exist about unusual transaction patterns?"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What compliance notes exist about unusual transaction patterns?"}]}]}$$
);

-- ............................................................................

-- Q: "Find any SAR summaries related to parties in the Cayman Islands"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Find any SAR summaries related to parties in the Cayman Islands"}]}]}$$
);

-- ............................................................................

-- Q: "What did the last site visit report say about Orion Holdings?"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What did the last site visit report say about Orion Holdings?"}]}]}$$
);


-- ============================================================================
-- DEMO 4: MULTI-TOOL ORCHESTRATION (Agent combining tools)
-- ============================================================================
-- These queries require the agent to combine multiple tools in a single
-- response — e.g., querying structured data AND searching notes, or
-- querying data AND then invoking an action.
-- ============================================================================

-- Q: "Give me the full picture on PTY-000007 including any compliance notes"
-- Expected: Agent calls party_360 (SP) + search_compliance_notes (Search)
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Give me the full picture on PTY-000007 including any compliance notes"}]}]}$$
);

-- ............................................................................

-- Q: "Which high-risk parties have overdue reviews AND screening hits?"
-- Expected: Agent queries COMPLIANCE_SV (Analyst) + possibly get_pdd_overdue (SP)
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Which high-risk parties have overdue reviews AND screening hits?"}]}]}$$
);

-- ............................................................................

-- Q: "Run screening on all parties that are overdue for PDD"
-- Expected: Agent calls get_pdd_overdue first, then run_screening for each
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Run screening on all parties that are overdue for PDD"}]}]}$$
);


-- ============================================================================
-- DEMO 5: END-TO-END COMPLIANCE WORKFLOW
-- ============================================================================
-- Walk through a complete compliance workflow using the agent.
-- Each step builds on the previous one, demonstrating how a compliance
-- officer would use the agent in their daily work.
--
-- NOTE: For multi-turn conversations, use the Snowsight Agent UI which
-- maintains conversation context between messages. The SQL examples below
-- are independent calls — the agent won't remember prior steps.
-- ============================================================================

-- Step 1: Identify overdue reviews
-- "Show me parties overdue for periodic review"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Show me parties overdue for periodic review"}]}]}$$
);

-- Step 2: Run screening on a flagged party (replace PTY-XXXXXX with a result from Step 1)
-- "Run screening on PTY-XXXXXX"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Run screening on PTY-000010"}]}]}$$
);

-- Step 3: Check risk and compliance notes
-- "What is the current risk rating and any compliance notes for PTY-000010?"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What is the current risk rating and any compliance notes for PTY-000010?"}]}]}$$
);

-- Step 4: Initiate EDD if warranted
-- "Initiate an EDD review for PTY-000010 - trigger: overdue PDD with screening hit"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Initiate an EDD review for PTY-000010 - trigger: overdue PDD with screening hit"}]}]}$$
);

-- Step 5: Update risk rating based on findings
-- "Update the risk rating for PTY-000010 to HIGH based on the screening results"
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Update the risk rating for PTY-000010 to HIGH based on the screening results"}]}]}$$
);


-- ============================================================================
-- APPENDIX A: INTERACTING VIA SNOWSIGHT UI
-- ============================================================================
-- 1. Navigate to Snowsight → AI & ML → Cortex Agents
-- 2. Select COMPLIANCE_AGENT
-- 3. Type questions directly in the chat interface
-- 4. The UI supports multi-turn conversations with full context
-- 5. Sample questions are pre-loaded from the agent definition
--
-- The Snowsight UI is the recommended way to interact with the agent
-- for multi-turn workflows (Demo 5 above).
-- ============================================================================


-- ============================================================================
-- APPENDIX B: INTERACTING VIA REST API
-- ============================================================================
-- You can also call the agent programmatically via the Snowflake REST API.
-- This is useful for integrating the agent into external applications.
--
-- Endpoint:
--   POST https://<account>.snowflakecomputing.com/api/v2/cortex/agent:run
--
-- Example curl command (replace <account> and <token>):
/*

curl -X POST \
  "https://<account>.snowflakecomputing.com/api/v2/cortex/agent:run" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -H "X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT" \
  -d '{
    "agent_name": "GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT",
    "query": "Which parties are overdue for PDD review?",
    "stream": false
  }'

*/
-- ============================================================================


-- ============================================================================
-- APPENDIX C: CLEANUP (Optional)
-- ============================================================================
-- To remove the agent and all workshop objects:

-- DROP AGENT IF EXISTS GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT;
-- See 01_setup.sql for full database cleanup.
