-- ============================================================
-- AGENT BLUEPRINT — Payment Stack (from Agent-Pay)
-- schema.org alignment: schema:PayAction, schema:Invoice
-- Source: github.com/AGenNext/Agent-Pay (schema/payment_core.surql
--         + schema/payment_extensions.surql)
-- Tables: payment_intent, payer_proof, receiver_acknowledgement,
--         payment_ledger, payment_status_audit,
--         payment_provider, provider_transaction,
--         payment_dispute, escrow_hold
-- ============================================================

-- ── Payment Intent ──────────────────────────────────────────
DEFINE TABLE IF NOT EXISTS payment_intent SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
      AND ($auth.id = payer_agent OR $auth.id = payee_agent OR $auth.role IN ["orchestrator", "admin"])
    FOR create WHERE $auth.id IS NOT NONE
    FOR update WHERE $auth.role IN ["orchestrator", "system", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id                 ON payment_intent TYPE record<payment_intent>;
DEFINE FIELD IF NOT EXISTS payer_agent        ON payment_intent TYPE record<agent>
  ASSERT $value != NONE;
DEFINE FIELD IF NOT EXISTS payee_agent        ON payment_intent TYPE record<agent>
  ASSERT $value != NONE;
DEFINE FIELD IF NOT EXISTS workflow_id        ON payment_intent TYPE option<string>;
DEFINE FIELD IF NOT EXISTS run_id             ON payment_intent TYPE option<string>;

DEFINE FIELD IF NOT EXISTS payment_mode       ON payment_intent TYPE string
  ASSERT $value IN [
    "human_to_agent", "agent_to_human",
    "agent_to_agent", "human_to_human",
    "direct_payment", "provider_payment"
  ]
  DEFAULT "agent_to_agent";

DEFINE FIELD IF NOT EXISTS service_type       ON payment_intent TYPE option<string>;

-- Monetary fields — decimal for financial precision
DEFINE FIELD IF NOT EXISTS amount             ON payment_intent TYPE decimal
  ASSERT $value != NONE AND $value >= 0dec;
DEFINE FIELD IF NOT EXISTS currency           ON payment_intent TYPE string
  ASSERT string::len($value) = 3;  -- ISO 4217 e.g. INR, USD

DEFINE FIELD IF NOT EXISTS status             ON payment_intent TYPE string
  DEFAULT "requested"
  ASSERT $value IN [
    "requested", "authorized",
    "payer_proof_submitted", "receiver_acknowledged",
    "settled", "reconciled",
    "rejected", "cancelled", "refunded",
    "disputed", "expired",
    "proof_missing", "acknowledgement_missing"
  ];

-- Authorization chain
DEFINE FIELD IF NOT EXISTS authorization_ref  ON payment_intent TYPE option<string>;
DEFINE FIELD IF NOT EXISTS authorized_by      ON payment_intent TYPE option<record<agent>>;
DEFINE FIELD IF NOT EXISTS authorized_at      ON payment_intent TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS authorization_reason ON payment_intent TYPE option<string>;

-- Idempotency (prevents duplicate charges)
DEFINE FIELD IF NOT EXISTS idempotency_key    ON payment_intent TYPE string
  ASSERT $value != NONE AND string::len($value) > 0;

DEFINE FIELD IF NOT EXISTS expires_at         ON payment_intent TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS metadata           ON payment_intent TYPE option<object>;
DEFINE FIELD IF NOT EXISTS created_by         ON payment_intent TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS created_at         ON payment_intent TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at         ON payment_intent TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS idx_pi_status      ON payment_intent COLUMNS status;
DEFINE INDEX IF NOT EXISTS idx_pi_run         ON payment_intent COLUMNS run_id;
DEFINE INDEX IF NOT EXISTS idx_pi_payer       ON payment_intent COLUMNS payer_agent;
DEFINE INDEX IF NOT EXISTS idx_pi_payee       ON payment_intent COLUMNS payee_agent;
DEFINE INDEX IF NOT EXISTS idx_pi_idempotency ON payment_intent COLUMNS idempotency_key UNIQUE;

-- ── Payer Proof ─────────────────────────────────────────────
DEFINE TABLE IF NOT EXISTS payer_proof SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.role IN ["orchestrator", "admin"]
    FOR create WHERE $auth.id IS NOT NONE
    FOR update WHERE $auth.role IN ["system", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id                  ON payer_proof TYPE record<payer_proof>;
DEFINE FIELD IF NOT EXISTS payment_intent_id   ON payer_proof TYPE record<payment_intent>
  ASSERT $value != NONE;
DEFINE FIELD IF NOT EXISTS proof_type          ON payer_proof TYPE string
  ASSERT $value IN [
    "provider_receipt", "provider_webhook",
    "blockchain_tx", "signed_message",
    "bank_reference", "upi_reference",
    "internal_ledger_entry"
  ];
DEFINE FIELD IF NOT EXISTS proof_payload_hash  ON payer_proof TYPE string
  ASSERT $value != NONE;
DEFINE FIELD IF NOT EXISTS proof_payload_ref   ON payer_proof TYPE option<string>;
DEFINE FIELD IF NOT EXISTS external_reference  ON payer_proof TYPE option<string>;
DEFINE FIELD IF NOT EXISTS submitted_by        ON payer_proof TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS submitted_at        ON payer_proof TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS verification_method ON payer_proof TYPE option<string>;
DEFINE FIELD IF NOT EXISTS verification_status ON payer_proof TYPE string
  DEFAULT "pending"
  ASSERT $value IN ["pending", "verified", "failed", "expired", "revoked"];
DEFINE FIELD IF NOT EXISTS verified_at         ON payer_proof TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS expires_at          ON payer_proof TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at          ON payer_proof TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at          ON payer_proof TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS idx_pp_intent  ON payer_proof COLUMNS payment_intent_id;
DEFINE INDEX IF NOT EXISTS idx_pp_status  ON payer_proof COLUMNS verification_status;

-- ── Receiver Acknowledgement ─────────────────────────────────
DEFINE TABLE IF NOT EXISTS receiver_acknowledgement SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.role IN ["orchestrator", "admin"]
    FOR create WHERE $auth.id IS NOT NONE
    FOR update WHERE $auth.role IN ["system", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id                  ON receiver_acknowledgement TYPE record<receiver_acknowledgement>;
DEFINE FIELD IF NOT EXISTS payment_intent_id   ON receiver_acknowledgement TYPE record<payment_intent>
  ASSERT $value != NONE;
DEFINE FIELD IF NOT EXISTS ack_type            ON receiver_acknowledgement TYPE string
  ASSERT $value IN [
    "signed_receipt", "provider_confirmation",
    "platform_acknowledgement", "wallet_acknowledgement"
  ];
DEFINE FIELD IF NOT EXISTS ack_payload_hash    ON receiver_acknowledgement TYPE string;
DEFINE FIELD IF NOT EXISTS ack_signature       ON receiver_acknowledgement TYPE option<string>;
DEFINE FIELD IF NOT EXISTS signature_algorithm ON receiver_acknowledgement TYPE option<string>;
DEFINE FIELD IF NOT EXISTS signed_by           ON receiver_acknowledgement TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS signed_at           ON receiver_acknowledgement TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS verification_method ON receiver_acknowledgement TYPE option<string>;
DEFINE FIELD IF NOT EXISTS verification_status ON receiver_acknowledgement TYPE string
  DEFAULT "pending"
  ASSERT $value IN ["pending", "verified", "failed", "revoked"];
DEFINE FIELD IF NOT EXISTS verified_at         ON receiver_acknowledgement TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at          ON receiver_acknowledgement TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at          ON receiver_acknowledgement TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS idx_ra_intent  ON receiver_acknowledgement COLUMNS payment_intent_id;
DEFINE INDEX IF NOT EXISTS idx_ra_status  ON receiver_acknowledgement COLUMNS verification_status;

-- ── Payment Ledger (AP/AR) ───────────────────────────────────
DEFINE TABLE IF NOT EXISTS payment_ledger SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.role IN ["orchestrator", "admin"]
    FOR create WHERE $auth.role IN ["system", "orchestrator", "admin"]
    FOR update WHERE $auth.role IN ["system", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id                     ON payment_ledger TYPE record<payment_ledger>;
DEFINE FIELD IF NOT EXISTS payment_intent_id      ON payment_ledger TYPE record<payment_intent>
  ASSERT $value != NONE;
DEFINE FIELD IF NOT EXISTS payer                  ON payment_ledger TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS receiver               ON payment_ledger TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS amount                 ON payment_ledger TYPE decimal
  ASSERT $value >= 0dec;
DEFINE FIELD IF NOT EXISTS currency               ON payment_ledger TYPE string
  ASSERT string::len($value) = 3;

-- AP side
DEFINE FIELD IF NOT EXISTS payable_status         ON payment_ledger TYPE string
  DEFAULT "payable_open"
  ASSERT $value IN [
    "payable_open", "payable_authorized",
    "payable_settled", "payable_cancelled", "payable_refunded"
  ];

-- AR side
DEFINE FIELD IF NOT EXISTS receivable_status      ON payment_ledger TYPE string
  DEFAULT "receivable_open"
  ASSERT $value IN [
    "receivable_open", "receivable_expected",
    "receivable_settled", "receivable_cancelled", "receivable_refunded"
  ];

-- Delivery
DEFINE FIELD IF NOT EXISTS delivery_status        ON payment_ledger TYPE string
  DEFAULT "service_not_started"
  ASSERT $value IN [
    "service_not_started", "service_pending",
    "service_delivered", "service_failed", "service_disputed"
  ];

-- Settlement
DEFINE FIELD IF NOT EXISTS settlement_status      ON payment_ledger TYPE string
  DEFAULT "not_started"
  ASSERT $value IN [
    "not_started", "settlement_pending",
    "settled", "failed", "refunded"
  ];

-- Reconciliation
DEFINE FIELD IF NOT EXISTS reconciliation_status  ON payment_ledger TYPE string
  DEFAULT "not_started"
  ASSERT $value IN ["not_started", "pending", "reconciled", "failed"];

-- Proof references
DEFINE FIELD IF NOT EXISTS payer_proof_ref          ON payment_ledger TYPE option<record<payer_proof>>;
DEFINE FIELD IF NOT EXISTS receiver_ack_ref         ON payment_ledger TYPE option<record<receiver_acknowledgement>>;
DEFINE FIELD IF NOT EXISTS delivery_evidence_ref    ON payment_ledger TYPE option<string>;
DEFINE FIELD IF NOT EXISTS provider_transaction_ref ON payment_ledger TYPE option<string>;

-- Dispute + errors
DEFINE FIELD IF NOT EXISTS dispute_status          ON payment_ledger TYPE option<string>;
DEFINE FIELD IF NOT EXISTS reconciliation_errors   ON payment_ledger TYPE option<array<string>>;

-- Dates
DEFINE FIELD IF NOT EXISTS transaction_date        ON payment_ledger TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS settlement_date         ON payment_ledger TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at              ON payment_ledger TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at              ON payment_ledger TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS idx_pl_intent       ON payment_ledger COLUMNS payment_intent_id;
DEFINE INDEX IF NOT EXISTS idx_pl_payer        ON payment_ledger COLUMNS payer;
DEFINE INDEX IF NOT EXISTS idx_pl_receiver     ON payment_ledger COLUMNS receiver;
DEFINE INDEX IF NOT EXISTS idx_pl_settlement   ON payment_ledger COLUMNS settlement_status;
DEFINE INDEX IF NOT EXISTS idx_pl_recon        ON payment_ledger COLUMNS reconciliation_status;

-- ── Payment Status Audit ─────────────────────────────────────
DEFINE TABLE IF NOT EXISTS payment_status_audit SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.role IN ["orchestrator", "admin"]
    FOR create WHERE $auth.id IS NOT NONE
    FOR update, delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id                 ON payment_status_audit TYPE record<payment_status_audit>;
DEFINE FIELD IF NOT EXISTS payment_intent_id  ON payment_status_audit TYPE record<payment_intent>;
DEFINE FIELD IF NOT EXISTS old_status         ON payment_status_audit TYPE option<string>;
DEFINE FIELD IF NOT EXISTS new_status         ON payment_status_audit TYPE string;
DEFINE FIELD IF NOT EXISTS changed_by         ON payment_status_audit TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS changed_by_role    ON payment_status_audit TYPE string
  ASSERT $value IN ["payer", "receiver", "platform", "provider", "system"];
DEFINE FIELD IF NOT EXISTS reason             ON payment_status_audit TYPE option<string>;
DEFINE FIELD IF NOT EXISTS evidence_ref       ON payment_status_audit TYPE option<string>;
DEFINE FIELD IF NOT EXISTS created_at         ON payment_status_audit TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS idx_psa_intent  ON payment_status_audit COLUMNS payment_intent_id;
DEFINE INDEX IF NOT EXISTS idx_psa_created ON payment_status_audit COLUMNS created_at;

-- ── Payment Provider ─────────────────────────────────────────
DEFINE TABLE IF NOT EXISTS payment_provider SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create, update WHERE $auth.role = "admin"
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id                    ON payment_provider TYPE record<payment_provider>;
DEFINE FIELD IF NOT EXISTS provider_name         ON payment_provider TYPE string
  ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS provider_type         ON payment_provider TYPE string
  ASSERT $value IN ["stripe", "paypal", "upi", "razorpay", "bank_transfer", "crypto", "internal"];
DEFINE FIELD IF NOT EXISTS integration_mode      ON payment_provider TYPE string
  ASSERT $value IN ["live", "sandbox", "mock"];
DEFINE FIELD IF NOT EXISTS public_key_ref        ON payment_provider TYPE option<string>;
DEFINE FIELD IF NOT EXISTS secret_key_ref        ON payment_provider TYPE option<string>;
DEFINE FIELD IF NOT EXISTS webhook_signing_key_ref ON payment_provider TYPE option<string>;
DEFINE FIELD IF NOT EXISTS status                ON payment_provider TYPE string
  DEFAULT "active"
  ASSERT $value IN ["active", "inactive", "suspended"];
DEFINE FIELD IF NOT EXISTS last_verified_at      ON payment_provider TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at            ON payment_provider TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at            ON payment_provider TYPE datetime DEFAULT time::now();

-- ── Provider Transaction ─────────────────────────────────────
DEFINE TABLE IF NOT EXISTS provider_transaction SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.role IN ["orchestrator", "admin"]
    FOR create WHERE $auth.role IN ["system", "admin"]
    FOR update WHERE $auth.role IN ["system", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id                      ON provider_transaction TYPE record<provider_transaction>;
DEFINE FIELD IF NOT EXISTS payment_intent_id       ON provider_transaction TYPE record<payment_intent>;
DEFINE FIELD IF NOT EXISTS provider_id             ON provider_transaction TYPE record<payment_provider>;
DEFINE FIELD IF NOT EXISTS external_transaction_id ON provider_transaction TYPE string;
DEFINE FIELD IF NOT EXISTS provider_status         ON provider_transaction TYPE string DEFAULT "pending";
DEFINE FIELD IF NOT EXISTS amount                  ON provider_transaction TYPE decimal
  ASSERT $value >= 0dec;
DEFINE FIELD IF NOT EXISTS currency                ON provider_transaction TYPE string
  ASSERT string::len($value) = 3;
DEFINE FIELD IF NOT EXISTS idempotency_key         ON provider_transaction TYPE string;
DEFINE FIELD IF NOT EXISTS provider_payload_hash   ON provider_transaction TYPE option<string>;
DEFINE FIELD IF NOT EXISTS provider_payload_ref    ON provider_transaction TYPE option<string>;
DEFINE FIELD IF NOT EXISTS verified_at             ON provider_transaction TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at              ON provider_transaction TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at              ON provider_transaction TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS idx_pt_external_unique    ON provider_transaction COLUMNS provider_id, external_transaction_id UNIQUE;
DEFINE INDEX IF NOT EXISTS idx_pt_idempotency_unique ON provider_transaction COLUMNS provider_id, idempotency_key UNIQUE;

-- ── Payment Dispute ──────────────────────────────────────────
DEFINE TABLE IF NOT EXISTS payment_dispute SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.role IN ["orchestrator", "admin"]
    FOR create WHERE $auth.id IS NOT NONE
    FOR update WHERE $auth.role IN ["orchestrator", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id                   ON payment_dispute TYPE record<payment_dispute>;
DEFINE FIELD IF NOT EXISTS payment_intent_id    ON payment_dispute TYPE record<payment_intent>;
DEFINE FIELD IF NOT EXISTS initiated_by         ON payment_dispute TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS dispute_reason       ON payment_dispute TYPE string;
DEFINE FIELD IF NOT EXISTS dispute_status       ON payment_dispute TYPE string
  DEFAULT "open"
  ASSERT $value IN ["open", "under_review", "resolved", "escalated", "closed"];
DEFINE FIELD IF NOT EXISTS dispute_evidence_refs ON payment_dispute TYPE option<array<string>>;
DEFINE FIELD IF NOT EXISTS assigned_to          ON payment_dispute TYPE option<record<agent>>;
DEFINE FIELD IF NOT EXISTS resolution_type      ON payment_dispute TYPE option<string>
  VALUE IF $value != NONE THEN
    IF $value IN ["refund", "partial_refund", "no_action", "escalated"] THEN $value ELSE NONE END
  END;
DEFINE FIELD IF NOT EXISTS resolved_at          ON payment_dispute TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at           ON payment_dispute TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at           ON payment_dispute TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS idx_pd_intent  ON payment_dispute COLUMNS payment_intent_id;
DEFINE INDEX IF NOT EXISTS idx_pd_status  ON payment_dispute COLUMNS dispute_status;

-- ── Escrow Hold ──────────────────────────────────────────────
DEFINE TABLE IF NOT EXISTS escrow_hold SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.role IN ["orchestrator", "admin"]
    FOR create WHERE $auth.role IN ["orchestrator", "system", "admin"]
    FOR update WHERE $auth.role IN ["system", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id                    ON escrow_hold TYPE record<escrow_hold>;
DEFINE FIELD IF NOT EXISTS payment_intent_id     ON escrow_hold TYPE record<payment_intent>;
DEFINE FIELD IF NOT EXISTS holder_role           ON escrow_hold TYPE string
  ASSERT $value IN ["platform", "smart_contract", "bank", "agent"];
DEFINE FIELD IF NOT EXISTS amount                ON escrow_hold TYPE decimal
  ASSERT $value >= 0dec;
DEFINE FIELD IF NOT EXISTS currency              ON escrow_hold TYPE string
  ASSERT string::len($value) = 3;
DEFINE FIELD IF NOT EXISTS hold_status           ON escrow_hold TYPE string
  DEFAULT "created"
  ASSERT $value IN ["created", "held", "released", "cancelled", "expired"];
DEFINE FIELD IF NOT EXISTS release_condition     ON escrow_hold TYPE string;
DEFINE FIELD IF NOT EXISTS release_triggered_at  ON escrow_hold TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS released_to           ON escrow_hold TYPE option<record<agent>>;
DEFINE FIELD IF NOT EXISTS held_at               ON escrow_hold TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at            ON escrow_hold TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at            ON escrow_hold TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS idx_eh_intent  ON escrow_hold COLUMNS payment_intent_id;
DEFINE INDEX IF NOT EXISTS idx_eh_status  ON escrow_hold COLUMNS hold_status;

-- ── Graph edges: agent -> initiates/receives -> payment_intent ──
DEFINE TABLE IF NOT EXISTS initiates_payment SCHEMAFULL TYPE RELATION IN agent OUT payment_intent
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create WHERE $auth.id IS NOT NONE
    FOR update, delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS initiated_at ON initiates_payment TYPE datetime DEFAULT time::now();

DEFINE TABLE IF NOT EXISTS receives_payment SCHEMAFULL TYPE RELATION IN agent OUT payment_intent
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create WHERE $auth.id IS NOT NONE
    FOR update, delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS expected_at ON receives_payment TYPE option<datetime>;
