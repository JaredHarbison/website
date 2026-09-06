# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_06_000001) do
  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "ask_tokens", force: :cascade do |t|
    t.integer "opportunity_id"
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.string "status", default: "available", null: false
    t.string "claim_key"
    t.datetime "claimed_at"
    t.datetime "submitted_at"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "exported_at"
    t.string "access_scope", default: "opportunity", null: false
    t.index ["access_scope"], name: "index_ask_tokens_on_access_scope"
    t.index ["claim_key", "status"], name: "index_ask_tokens_on_claim_key_and_status", unique: true, where: "claim_key IS NOT NULL AND status IN ('claimed', 'submitted')"
    t.index ["opportunity_id"], name: "index_ask_tokens_on_opportunity_id"
    t.index ["status", "expires_at"], name: "index_ask_tokens_on_status_and_expires_at"
    t.index ["status", "exported_at"], name: "index_ask_tokens_on_status_and_exported_at"
    t.index ["token_digest"], name: "index_ask_tokens_on_token_digest", unique: true
  end

  create_table "ask_usage_events", force: :cascade do |t|
    t.integer "opportunity_id"
    t.integer "ask_token_id"
    t.string "request_id", null: false
    t.string "session_digest", null: false
    t.string "status", null: false
    t.integer "estimated_cost_cents"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ask_token_id", "occurred_at"], name: "index_ask_usage_events_on_ask_token_id_and_occurred_at"
    t.index ["ask_token_id"], name: "index_ask_usage_events_on_ask_token_id"
    t.index ["opportunity_id"], name: "index_ask_usage_events_on_opportunity_id"
    t.index ["request_id"], name: "index_ask_usage_events_on_request_id", unique: true
    t.index ["session_digest", "occurred_at"], name: "index_ask_usage_events_on_session_digest_and_occurred_at"
  end

  create_table "candidate_context_records", force: :cascade do |t|
    t.string "stable_key", null: false
    t.string "corpus_version", null: false
    t.string "category", null: false
    t.string "approval_status", default: "draft", null: false
    t.string "privacy_classification", default: "private", null: false
    t.text "purpose"
    t.text "guidance", null: false
    t.json "source_references", default: [], null: false
    t.json "provenance", default: {}, null: false
    t.json "affects", default: [], null: false
    t.json "intent_tags", default: [], null: false
    t.json "relationships", default: {}, null: false
    t.integer "priority", default: 0, null: false
    t.datetime "retired_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["corpus_version", "approval_status"], name: "idx_on_corpus_version_approval_status_2b95c06cdc"
    t.index ["stable_key"], name: "index_candidate_context_records_on_stable_key", unique: true
  end

  create_table "engagement_events", force: :cascade do |t|
    t.integer "opportunity_id"
    t.integer "ask_token_id"
    t.string "event_type", null: false
    t.string "event_key", null: false
    t.string "session_digest", null: false
    t.string "ip_digest"
    t.string "user_agent_class"
    t.json "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.boolean "meaningful", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "activity_class", default: "unclassified", null: false
    t.index ["activity_class"], name: "index_engagement_events_on_activity_class"
    t.index ["ask_token_id"], name: "index_engagement_events_on_ask_token_id"
    t.index ["event_key"], name: "index_engagement_events_on_event_key", unique: true
    t.index ["event_type", "meaningful"], name: "index_engagement_events_on_event_type_and_meaningful"
    t.index ["opportunity_id", "occurred_at"], name: "index_engagement_events_on_opportunity_id_and_occurred_at"
    t.index ["opportunity_id"], name: "index_engagement_events_on_opportunity_id"
  end

  create_table "knowledge_entries", force: :cascade do |t|
    t.string "title", null: false
    t.text "body", null: false
    t.text "short_body"
    t.string "entry_type", null: false
    t.string "approval_status", default: "candidate", null: false
    t.string "visibility", default: "private", null: false
    t.string "confidence"
    t.string "source_type", null: false
    t.string "source_reference", null: false
    t.string "source_url"
    t.string "public_url"
    t.string "source_fingerprint", null: false
    t.json "metadata", default: {}, null: false
    t.json "reviewer_edits", default: {}, null: false
    t.string "reviewed_by"
    t.text "reviewer_note"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "embedding"
    t.string "embedding_model"
    t.datetime "embedding_generated_at"
    t.index ["approval_status", "visibility"], name: "index_knowledge_entries_on_approval_status_and_visibility"
    t.index ["source_fingerprint"], name: "index_knowledge_entries_on_source_fingerprint"
    t.index ["source_reference"], name: "index_knowledge_entries_on_source_reference", unique: true
  end

  create_table "opportunities", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "company", null: false
    t.string "role_title", null: false
    t.string "tracker_source"
    t.string "application_state", default: "pre_application", null: false
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "purpose"
    t.index ["external_id"], name: "index_opportunities_on_external_id", unique: true
  end

  create_table "resume_verifications", force: :cascade do |t|
    t.integer "opportunity_id"
    t.integer "ask_token_id"
    t.string "token_digest", null: false
    t.string "email", null: false
    t.string "session_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "verified_at"
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ask_token_id", "created_at"], name: "index_resume_verifications_on_ask_token_id_and_created_at"
    t.index ["ask_token_id"], name: "index_resume_verifications_on_ask_token_id"
    t.index ["opportunity_id"], name: "index_resume_verifications_on_opportunity_id"
    t.index ["token_digest"], name: "index_resume_verifications_on_token_digest", unique: true
  end

  add_foreign_key "ask_tokens", "opportunities"
  add_foreign_key "ask_usage_events", "ask_tokens"
  add_foreign_key "ask_usage_events", "opportunities"
  add_foreign_key "engagement_events", "ask_tokens"
  add_foreign_key "engagement_events", "opportunities"
  add_foreign_key "resume_verifications", "ask_tokens"
  add_foreign_key "resume_verifications", "opportunities"
end
