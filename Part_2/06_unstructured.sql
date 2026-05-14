/*=============================================================================
  COMPLIANCE AGENT WORKSHOP - STEP 6: UNSTRUCTURED DATA & CORTEX SEARCH
  ===========================================================================
  Creates a table for free-text compliance notes (EDD narratives, SAR
  summaries, site visits, analyst memos) and a Cortex Search Service
  to enable natural-language retrieval by the Cortex Agent.

  Prerequisites: Run 01_setup.sql (creates GENERIC_DB.DOCUMENTS schema)
  Run as: CPR_WORKSHOP_ROLE
  ===========================================================================*/

-- ============================================================================
-- 6.0 ROLE & WAREHOUSE
-- ============================================================================

USE ROLE CPR_WORKSHOP_ROLE;
USE WAREHOUSE CPR_WORKSHOP_WH;

-- ============================================================================
-- 6.1 COMPLIANCE NOTES TABLE
-- ============================================================================

CREATE OR REPLACE TABLE GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES (
    NOTE_ID         VARCHAR(20)     NOT NULL PRIMARY KEY,
    PARTY_KEY       VARCHAR(15)     NOT NULL,
    NOTE_TYPE       VARCHAR(30)     NOT NULL,  -- EDD_NARRATIVE, SAR_SUMMARY, SITE_VISIT, ANALYST_MEMO, RISK_ASSESSMENT, MEETING_NOTES
    AUTHOR          VARCHAR(100)    NOT NULL,
    CREATED_AT      TIMESTAMP_NTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    SUBJECT         VARCHAR(200)    NOT NULL,
    CONTENT         VARCHAR(5000)   NOT NULL,
    TAGS            ARRAY
)
COMMENT = 'Free-text compliance memos, EDD narratives, SAR summaries, and analyst notes';

-- ============================================================================
-- 6.2 SEED COMPLIANCE NOTES (~30 realistic memos)
-- ============================================================================

INSERT ALL

-- ── EDD Narratives ──────────────────────────────────────────────────────────

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-001', 'PTY-007', 'EDD_NARRATIVE', 'Sarah Chen',
    '2025-01-15 09:30:00'::TIMESTAMP_NTZ,
    'EDD Narrative — PTY-007 Offshore Structure Review',
    'Enhanced due diligence conducted on PTY-007 following identification of multi-layered offshore holding structure spanning Cayman Islands, BVI, and Luxembourg. Ultimate beneficial ownership traced through three intermediary SPVs to a family trust registered in Liechtenstein. Source of wealth declared as real estate development in Southeast Asia, partially corroborated by public filings. Transaction volumes exceed declared business activity by approximately 40%, warranting continued enhanced monitoring. Recommend semi-annual review cycle with transaction pattern analysis.',
    ARRAY_CONSTRUCT('offshore', 'UBO', 'complex_structure', 'high_risk')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-002', 'PTY-012', 'EDD_NARRATIVE', 'James Mitchell',
    '2025-02-20 14:15:00'::TIMESTAMP_NTZ,
    'EDD Narrative — PTY-012 PEP Relationship Assessment',
    'PTY-012 identified as having close family ties to a senior government official in jurisdiction flagged as high-corruption-risk by Transparency International. The party serves as director of two companies that have received government contracts totaling approximately EUR 15M over the past three years. While no direct sanctions hits were found, the proximity to political power and concentration of government-linked revenue streams present elevated money laundering risk. Source of funds documentation requested and partially received. Recommend quarterly monitoring with focus on government contract payments.',
    ARRAY_CONSTRUCT('PEP', 'government_contracts', 'corruption_risk', 'critical')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-003', 'PTY-023', 'EDD_NARRATIVE', 'Priya Sharma',
    '2025-03-10 11:00:00'::TIMESTAMP_NTZ,
    'EDD Narrative — PTY-023 Trade Finance Discrepancies',
    'Review of PTY-023 trade finance activity reveals pricing anomalies on commodities invoices. Invoice values for palm oil shipments from Malaysia to Singapore were approximately 25-30% above prevailing market rates for three consecutive months. Counterparty analysis shows the receiving entity shares a registered address with two other clients currently under enhanced monitoring. Documentary trade documentation appears authentic but volume claims could not be independently verified against shipping manifests. Trade-based money laundering indicators present. Escalation to MLRO recommended.',
    ARRAY_CONSTRUCT('trade_finance', 'pricing_anomaly', 'TBML', 'escalation')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-004', 'PTY-045', 'EDD_NARRATIVE', 'David Okonkwo',
    '2025-01-28 16:45:00'::TIMESTAMP_NTZ,
    'EDD Narrative — PTY-045 Rapid Wealth Accumulation',
    'PTY-045 onboarded 18 months ago declaring modest income from consulting services. Account activity has since shown significant and unexplained growth, with monthly inflows increasing from GBP 8,000 to over GBP 150,000 within six months. Funds originate from multiple jurisdictions including UAE, Hong Kong, and Nigeria. Client provided supplementary documentation citing cryptocurrency trading gains, but wallet addresses provided show limited on-chain activity. Recommend maintaining CRITICAL risk rating and requesting further substantiation of income sources.',
    ARRAY_CONSTRUCT('rapid_growth', 'crypto', 'unexplained_wealth', 'critical')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-005', 'PTY-089', 'EDD_NARRATIVE', 'Maria Gonzalez',
    '2025-04-05 10:20:00'::TIMESTAMP_NTZ,
    'EDD Narrative — PTY-089 Shell Company Indicators',
    'PTY-089 exhibits characteristics consistent with shell company typology: minimal employees (declared: 2), registered at a virtual office address in Delaware, no discernible online presence or physical operations. Party acts primarily as an intermediary in cross-border payments between entities in Central America and Europe. Beneficial owner is a dual-national with ties to a jurisdiction under FATF grey list. Despite repeated requests, no audited financial statements have been produced. Recommend exit consideration if documentation not provided within 60 days.',
    ARRAY_CONSTRUCT('shell_company', 'FATF_grey_list', 'no_substance', 'exit_risk')
)

-- ── SAR Summaries ───────────────────────────────────────────────────────────

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-006', 'PTY-023', 'SAR_SUMMARY', 'Sarah Chen',
    '2025-04-12 09:00:00'::TIMESTAMP_NTZ,
    'SAR Filed — PTY-023 Trade-Based ML Indicators',
    'Suspicious Activity Report filed with national FIU regarding PTY-023 trade finance activity. Report covers the period January 2025 to March 2025 and documents repeated over-invoicing on commodity shipments, use of multiple intermediary accounts to layer funds, and connections to entities in jurisdictions with weak AML controls. Total suspicious transaction value: approximately USD 4.2M. Filing reference: SAR-2025-04-0892. Client not tipped off per regulatory requirements.',
    ARRAY_CONSTRUCT('SAR', 'FIU_filing', 'TBML', 'no_tipping_off')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-007', 'PTY-045', 'SAR_SUMMARY', 'James Mitchell',
    '2025-03-18 15:30:00'::TIMESTAMP_NTZ,
    'SAR Filed — PTY-045 Unexplained Cash Deposits',
    'Suspicious Activity Report filed regarding PTY-045 pattern of structured cash deposits just below reporting thresholds across multiple branch locations. Over a 90-day period, 47 individual cash deposits averaging GBP 7,800 each were made at 12 different branches. Total structured amount: GBP 366,600. Activity is inconsistent with declared consulting business. Filing reference: SAR-2025-03-0634. Account placed under enhanced transaction monitoring pending FIU response.',
    ARRAY_CONSTRUCT('SAR', 'structuring', 'smurfing', 'cash_deposits')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-008', 'PTY-034', 'SAR_SUMMARY', 'Priya Sharma',
    '2025-02-28 11:45:00'::TIMESTAMP_NTZ,
    'SAR Filed — PTY-034 Layering Through Third-Party Accounts',
    'SAR filed on PTY-034 for suspected layering activity. Funds received from a high-risk jurisdiction were rapidly dispersed across six domestic accounts held by apparently unrelated parties, then reconsolidated into a single investment account within 48 hours. Pattern repeated three times in Q4 2024 with increasing values. Total value: SGD 2.8M. Counterparties have since been identified as sharing the same corporate service provider. Filing reference: SAR-2025-02-0417.',
    ARRAY_CONSTRUCT('SAR', 'layering', 'third_party', 'Singapore')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-009', 'PTY-067', 'SAR_SUMMARY', 'David Okonkwo',
    '2025-05-01 08:15:00'::TIMESTAMP_NTZ,
    'SAR Filed — PTY-067 Sanctions Evasion Concern',
    'Internal investigation identified potential sanctions evasion by PTY-067. Wire transfers routed through intermediaries in Turkey and UAE appear designed to obscure the ultimate beneficiary, which may be an entity on the OFAC SDN list. Correspondent banking team flagged the transactions after SWIFT message analysis revealed inconsistent originator information. Total exposure: USD 1.1M across seven transactions. Filing reference: SAR-2025-05-0103. Immediate account restriction applied.',
    ARRAY_CONSTRUCT('SAR', 'sanctions_evasion', 'OFAC', 'account_restricted')
)

-- ── Site Visit Reports ──────────────────────────────────────────────────────

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-010', 'PTY-007', 'SITE_VISIT', 'Maria Gonzalez',
    '2025-02-10 17:00:00'::TIMESTAMP_NTZ,
    'Site Visit Report — PTY-007 Singapore Office',
    'Conducted on-site visit to PTY-007 registered office at One Raffles Place, Singapore. Office occupies half a floor with approximately 25 staff visible. Operations appear consistent with declared asset management activities. Met with CFO and compliance officer who provided access to internal transaction records. IT infrastructure and physical security measures appear adequate. Office signage and corporate branding consistent with public filings. Overall impression: legitimate operating business, though offshore subsidiary structure warrants continued monitoring.',
    ARRAY_CONSTRUCT('site_visit', 'Singapore', 'asset_management', 'satisfactory')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-011', 'PTY-089', 'SITE_VISIT', 'James Mitchell',
    '2025-03-22 14:00:00'::TIMESTAMP_NTZ,
    'Site Visit Report — PTY-089 Delaware Registered Address',
    'Attempted site visit to PTY-089 registered address in Wilmington, Delaware. Address is a commercial registered agent office providing virtual mailbox services. No dedicated office space, staff, or physical operations for PTY-089 at the location. Receptionist confirmed the entity uses mail forwarding only. This is consistent with the shell company indicators identified during EDD. No operational substance could be verified at this location. Findings shared with relationship manager and EDD team.',
    ARRAY_CONSTRUCT('site_visit', 'virtual_office', 'no_substance', 'Delaware')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-012', 'PTY-056', 'SITE_VISIT', 'Sarah Chen',
    '2025-04-18 10:30:00'::TIMESTAMP_NTZ,
    'Site Visit Report — PTY-056 Frankfurt Manufacturing Facility',
    'Visited PTY-056 manufacturing facility in Frankfurt industrial district. Large-scale production operation with approximately 200 employees on site. Inventory and production volumes appear consistent with declared export activity. Reviewed shipping documentation for Q1 2025 — volumes and destinations align with trade finance records. Company has invested significantly in automation and expansion, explaining the increase in credit facility utilisation. No adverse findings. Recommend downgrade from MEDIUM to LOW risk at next periodic review.',
    ARRAY_CONSTRUCT('site_visit', 'manufacturing', 'Frankfurt', 'satisfactory')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-013', 'PTY-012', 'SITE_VISIT', 'Priya Sharma',
    '2025-01-20 13:00:00'::TIMESTAMP_NTZ,
    'Site Visit Report — PTY-012 London Corporate Office',
    'Visited PTY-012 offices in Mayfair, London. Premium office space with approximately 15 staff. Business appears focused on government advisory and procurement consulting. Several government contract award letters displayed in reception. Director was unavailable for the meeting and sent a deputy instead, which is noted as the third consecutive postponement. Financial records access was limited citing client confidentiality. While the office itself appears legitimate, lack of transparency from senior management is a concern. Recommend maintaining HIGH risk and scheduling follow-up within 90 days.',
    ARRAY_CONSTRUCT('site_visit', 'London', 'PEP', 'limited_access', 'concern')
)

-- ── Analyst Memos ───────────────────────────────────────────────────────────

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-014', 'PTY-078', 'ANALYST_MEMO', 'David Okonkwo',
    '2025-03-05 09:45:00'::TIMESTAMP_NTZ,
    'Analyst Memo — PTY-078 Unusual Wire Transfer Pattern',
    'Transaction monitoring alert triggered for PTY-078 due to unusual wire transfer pattern. Over the past 60 days, the account received 23 inbound wires from 8 different countries, each in the range of USD 9,000-9,500. Funds were consolidated and transferred within 72 hours to a single account in Hong Kong. This pattern is consistent with collection account typology used in romance scam and business email compromise schemes. Recommend immediate enhanced monitoring and outreach to relationship manager for client explanation.',
    ARRAY_CONSTRUCT('TM_alert', 'wire_pattern', 'collection_account', 'BEC')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-015', 'PTY-034', 'ANALYST_MEMO', 'Maria Gonzalez',
    '2025-03-28 16:00:00'::TIMESTAMP_NTZ,
    'Analyst Memo — PTY-034 Network Analysis Findings',
    'Network analysis of PTY-034 transaction counterparties reveals a clustered pattern of interconnected entities. Six counterparties share overlapping directors, registered agents, and beneficial owners forming a closed loop. Transaction flows within this network show circular patterns: funds move A to B to C and return to A within 5-7 business days. Total circular flow value in Q1 2025: SGD 8.4M. This pattern is consistent with round-tripping for the purposes of creating artificial transaction history or inflating revenue. Recommend escalating to financial crime investigations.',
    ARRAY_CONSTRUCT('network_analysis', 'round_tripping', 'connected_parties', 'escalation')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-016', 'PTY-091', 'ANALYST_MEMO', 'Sarah Chen',
    '2025-04-22 11:30:00'::TIMESTAMP_NTZ,
    'Analyst Memo — PTY-091 Dormant Account Reactivation',
    'PTY-091 account was dormant for approximately 14 months before sudden reactivation with a series of large international transfers. Within the first week of reactivation, five outbound wires totaling EUR 2.3M were sent to accounts in Malta and Cyprus. The party had previously been rated LOW risk with minimal activity. Contact details on file are outdated and attempts to reach the party have been unsuccessful. Account ownership verification is required before further transactions are permitted. Temporary hold placed on outbound wires pending verification.',
    ARRAY_CONSTRUCT('dormant_reactivation', 'large_transfers', 'Malta', 'Cyprus', 'hold')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-017', 'PTY-015', 'ANALYST_MEMO', 'James Mitchell',
    '2025-02-14 10:00:00'::TIMESTAMP_NTZ,
    'Analyst Memo — PTY-015 Adverse Media Screening Hit',
    'Adverse media screening flagged PTY-015 in connection with a news article published by the Financial Times regarding a regulatory investigation in their home jurisdiction. The article names a subsidiary of PTY-015 as being under investigation for potential bribery of public officials in relation to infrastructure contracts. While no charges have been filed, the investigation is being conducted by the national anti-corruption agency. Recommend immediate risk rating upgrade to HIGH and initiation of EDD review. Relationship manager notified.',
    ARRAY_CONSTRUCT('adverse_media', 'bribery', 'regulatory_investigation', 'FT')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-018', 'PTY-042', 'ANALYST_MEMO', 'Priya Sharma',
    '2025-05-02 14:30:00'::TIMESTAMP_NTZ,
    'Analyst Memo — PTY-042 Cryptocurrency Exchange Nexus',
    'PTY-042 account shows increasing volume of transactions with known cryptocurrency exchanges and OTC desks. Monthly crypto-related transaction volume has grown from USD 50K to USD 1.2M over the past quarter. While cryptocurrency trading is not inherently suspicious, the rapid escalation and use of multiple unregulated exchanges in different jurisdictions raises concerns about potential regulatory arbitrage or conversion of illicitly obtained digital assets. Recommend enhanced TM rules for crypto-related flows and requesting updated source of funds declaration.',
    ARRAY_CONSTRUCT('cryptocurrency', 'OTC', 'regulatory_arbitrage', 'source_of_funds')
)

-- ── Risk Assessments ────────────────────────────────────────────────────────

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-019', 'PTY-007', 'RISK_ASSESSMENT', 'David Okonkwo',
    '2025-04-01 09:00:00'::TIMESTAMP_NTZ,
    'Annual Risk Assessment — PTY-007',
    'Annual risk assessment for PTY-007 completed. Overall risk rating maintained at HIGH. Key risk factors: complex multi-jurisdictional corporate structure (3 layers of SPVs), UBO through Liechtenstein trust, transaction volumes exceeding declared activity by 40%. Mitigating factors: site visit confirmed operational substance in Singapore, cooperation with information requests has improved, no adverse media hits in past 12 months. Risk score: 7.2/10. Recommendation: maintain HIGH with semi-annual review cycle. Next review due: October 2025.',
    ARRAY_CONSTRUCT('annual_review', 'risk_score', 'HIGH', 'semi_annual')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-020', 'PTY-056', 'RISK_ASSESSMENT', 'Sarah Chen',
    '2025-04-15 11:00:00'::TIMESTAMP_NTZ,
    'Risk Assessment — PTY-056 Downgrade Recommendation',
    'Risk assessment completed for PTY-056 following satisfactory site visit to Frankfurt manufacturing facility. All previously identified risk factors have been resolved: trade finance discrepancies explained by commodity price fluctuations, new audited financial statements received and reviewed, KYC refresh completed with updated beneficial ownership documentation. Transaction patterns are consistent with declared business. Recommend downgrade from MEDIUM to LOW risk. Risk score: 2.8/10. Annual review cycle appropriate.',
    ARRAY_CONSTRUCT('risk_downgrade', 'LOW', 'satisfactory', 'resolved')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-021', 'PTY-012', 'RISK_ASSESSMENT', 'Maria Gonzalez',
    '2025-03-30 15:00:00'::TIMESTAMP_NTZ,
    'Risk Assessment — PTY-012 Rating Upgrade to CRITICAL',
    'Risk assessment for PTY-012 recommends upgrade from HIGH to CRITICAL. Cumulative risk factors now exceed threshold: confirmed PEP relationship (senior government official family member), increasing government contract revenue concentration (now 85% of total), third consecutive refusal to provide full access during site visit, and new adverse media linking associated entities to a corruption investigation in neighbouring jurisdiction. Source of wealth verification remains incomplete after six months. Risk score: 9.1/10. Recommend quarterly review cycle and board-level reporting.',
    ARRAY_CONSTRUCT('risk_upgrade', 'CRITICAL', 'PEP', 'board_reporting')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-022', 'PTY-067', 'RISK_ASSESSMENT', 'James Mitchell',
    '2025-05-05 10:00:00'::TIMESTAMP_NTZ,
    'Risk Assessment — PTY-067 Post-SAR Review',
    'Post-SAR risk assessment for PTY-067. Account restricted following SAR filing for potential sanctions evasion. Investigation confirmed indirect payment flows to a sanctioned entity through Turkish and UAE intermediaries. The party claims transactions were legitimate trade payments and has engaged external counsel. Pending outcome of FIU investigation, account remains restricted to essential operational payments only. Risk rating: CRITICAL. Consider relationship exit if FIU confirms sanctions breach. Legal counsel advising on de-risking timeline and obligations.',
    ARRAY_CONSTRUCT('post_SAR', 'CRITICAL', 'sanctions', 'account_restricted', 'exit_risk')
)

-- ── Meeting Notes ───────────────────────────────────────────────────────────

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-023', 'PTY-007', 'MEETING_NOTES', 'Priya Sharma',
    '2025-03-15 16:00:00'::TIMESTAMP_NTZ,
    'Compliance Committee — PTY-007 Quarterly Review',
    'Compliance committee discussed PTY-007 at quarterly high-risk client review. Committee noted the improved cooperation from the client following the February site visit and acknowledged the operational substance confirmed in Singapore. However, concerns remain about the Liechtenstein trust structure and the 40% discrepancy between declared and actual transaction volumes. Committee approved maintaining HIGH risk rating with the following actions: (1) request detailed breakdown of transaction sources for Q1 2025, (2) engage external investigator to verify Liechtenstein trust structure, (3) review at next quarterly meeting.',
    ARRAY_CONSTRUCT('committee', 'quarterly_review', 'action_items')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-024', 'PTY-089', 'MEETING_NOTES', 'David Okonkwo',
    '2025-04-10 14:30:00'::TIMESTAMP_NTZ,
    'Exit Committee — PTY-089 Relationship Termination Discussion',
    'Exit committee convened to discuss potential termination of PTY-089 relationship. Presented evidence: virtual office with no substance, shell company characteristics, UBO on FATF grey-list jurisdiction, failure to provide audited financials after 60-day deadline. Committee unanimously approved relationship exit. Timeline: 90-day wind-down period to allow orderly closure of open positions. Client to be notified in writing within 5 business days. Residual funds to be returned via bank draft to verified account only. Legal team to handle any objections.',
    ARRAY_CONSTRUCT('exit_committee', 'relationship_exit', 'wind_down', 'unanimous')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-025', 'PTY-034', 'MEETING_NOTES', 'Sarah Chen',
    '2025-04-08 10:00:00'::TIMESTAMP_NTZ,
    'MLRO Briefing — PTY-034 Layering and Round-Tripping',
    'Briefed MLRO on PTY-034 findings from network analysis and SAR filing. MLRO agreed the evidence supports a layering and round-tripping pattern involving six interconnected entities. Directed the team to: (1) file supplementary SAR with updated network diagram, (2) extend enhanced monitoring to all identified connected entities, (3) coordinate with correspondent banking team to flag the network across all payment channels, (4) prepare board-level summary for next risk committee meeting. MLRO noted this case may be referred to law enforcement if pattern continues.',
    ARRAY_CONSTRUCT('MLRO', 'briefing', 'layering', 'law_enforcement')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-026', 'PTY-045', 'MEETING_NOTES', 'Maria Gonzalez',
    '2025-04-25 11:00:00'::TIMESTAMP_NTZ,
    'Case Conference — PTY-045 Structuring and Unexplained Wealth',
    'Case conference held with financial crime investigations team regarding PTY-045. Reviewed evidence of structured cash deposits (47 transactions below threshold) and inconsistent cryptocurrency trading claims. Investigations team confirmed that the wallet addresses provided by the client show minimal activity inconsistent with the claimed trading volume. Team agreed to: (1) request face-to-face meeting with client, (2) issue formal notice requiring full crypto exchange account statements, (3) consider account suspension if documentation not received within 30 days.',
    ARRAY_CONSTRUCT('case_conference', 'structuring', 'crypto', 'investigation')
)

-- ── Additional EDD Narratives ───────────────────────────────────────────────

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-027', 'PTY-003', 'EDD_NARRATIVE', 'James Mitchell',
    '2025-01-08 09:00:00'::TIMESTAMP_NTZ,
    'EDD Narrative — PTY-003 Shipping Company Review',
    'Enhanced due diligence on PTY-003, a bulk shipping company registered in Greece with operations across Mediterranean and Black Sea routes. Review triggered by vessel tracking showing port calls in sanctioned jurisdictions. Investigation confirmed two vessels made port calls in Crimea in Q3 2024, which the client attributes to emergency repairs. Vessel AIS data corroborates the emergency claim for one incident but is inconclusive for the second. Maritime sanctions compliance programme reviewed and found to have gaps in vessel routing controls. Recommend maintaining HIGH risk and requiring implementation of enhanced voyage screening within 60 days.',
    ARRAY_CONSTRUCT('maritime', 'sanctions', 'vessel_tracking', 'Crimea', 'AIS')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-028', 'PTY-098', 'EDD_NARRATIVE', 'Priya Sharma',
    '2025-04-28 13:00:00'::TIMESTAMP_NTZ,
    'EDD Narrative — PTY-098 Charitable Foundation Review',
    'EDD review of PTY-098, a charitable foundation registered in Geneva with stated focus on educational programmes in East Africa. Review triggered by large cash withdrawals (CHF 500K over 3 months) inconsistent with typical NGO payment patterns. Foundation provides grants to 12 local NGOs, three of which could not be independently verified as operating entities. Board of trustees includes two individuals previously associated with organisations flagged for terrorism financing. While no direct evidence of misuse was found, the combination of unverifiable beneficiaries and board composition presents material risk. Recommend CRITICAL rating and quarterly review.',
    ARRAY_CONSTRUCT('NGO', 'charitable', 'terrorism_financing', 'unverifiable', 'Geneva')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-029', 'PTY-015', 'RISK_ASSESSMENT', 'David Okonkwo',
    '2025-03-01 09:30:00'::TIMESTAMP_NTZ,
    'Risk Assessment — PTY-015 Post Adverse Media',
    'Interim risk assessment triggered by adverse media hit. PTY-015 previously rated MEDIUM based on standard commercial activity profile. Following Financial Times article linking subsidiary to bribery investigation, risk rating upgraded to HIGH. Key risk factors: active regulatory investigation, potential bribery of public officials, infrastructure contract concentration. Mitigating factors: investigation at early stage with no charges filed, client has engaged reputable external counsel, full cooperation with our KYC refresh requests. Risk score: 6.8/10. Enhanced monitoring applied to all accounts. Semi-annual PDD cycle implemented.',
    ARRAY_CONSTRUCT('adverse_media', 'risk_upgrade', 'HIGH', 'bribery_investigation')
)

INTO GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
    (NOTE_ID, PARTY_KEY, NOTE_TYPE, AUTHOR, CREATED_AT, SUBJECT, CONTENT, TAGS)
VALUES (
    'CN-030', 'PTY-012', 'ANALYST_MEMO', 'Sarah Chen',
    '2025-05-08 15:00:00'::TIMESTAMP_NTZ,
    'Analyst Memo — PTY-012 Updated PEP Screening',
    'Updated PEP screening for PTY-012 conducted following the quarterly refresh cycle. The associated government official has been promoted to a more senior position, increasing the PEP risk exposure. Additionally, two new beneficial owners were identified through corporate registry filings who were not previously disclosed to us. One of the new UBOs has a historical connection to an entity that appeared on the EU sanctions list (since delisted). Information request sent to client for updated beneficial ownership declaration and explanation of non-disclosure. Compliance committee to be briefed at next meeting.',
    ARRAY_CONSTRUCT('PEP', 'UBO', 'non_disclosure', 'EU_sanctions', 'quarterly_refresh')
)

SELECT 1;

-- ============================================================================
-- 6.3 CORTEX SEARCH SERVICE
-- ============================================================================
-- Creates a search service over the compliance notes table, enabling
-- natural-language retrieval of analyst memos, EDD narratives, and SAR
-- summaries by the Cortex Agent.

CREATE OR REPLACE CORTEX SEARCH SERVICE GENERIC_DB.DOCUMENTS.COMPLIANCE_SEARCH
    ON CONTENT
    ATTRIBUTES PARTY_KEY, NOTE_TYPE, AUTHOR, SUBJECT
    WAREHOUSE = CPR_WORKSHOP_WH
    TARGET_LAG = '1 hour'
AS (
    SELECT
        NOTE_ID,
        PARTY_KEY,
        NOTE_TYPE,
        AUTHOR,
        SUBJECT,
        CONTENT,
        CREATED_AT
    FROM GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Check note counts by type
-- SELECT NOTE_TYPE, COUNT(*) AS CNT
-- FROM GENERIC_DB.DOCUMENTS.COMPLIANCE_NOTES
-- GROUP BY NOTE_TYPE
-- ORDER BY CNT DESC;

-- Test Cortex Search (uncomment after service is active):
-- SELECT SNOWFLAKE.CORTEX.SEARCH(
--     'GENERIC_DB.DOCUMENTS.COMPLIANCE_SEARCH',
--     'parties with sanctions evasion concerns',
--     { 'limit': 5 }
-- );
