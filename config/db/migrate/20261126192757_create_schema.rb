# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :users do
      primary_key :id
      column :cpf, String, null: false, unique: true
      column :created_at, DateTime, null: false
    end

    # Every certificate seen for a user. A new one starts pending until an
    # existing session approves it or its waiting period ends.
    create_table :certificates do
      primary_key :id
      foreign_key :user_id, :users, null: false
      column :fingerprint, String, null: false, unique: true
      column :kind, String, null: false # pf or pj
      column :cnpj, String
      column :subject, String, null: false
      column :not_after, DateTime, null: false
      column :status, String, null: false # approved or pending
      column :approvable_after, DateTime
      column :created_at, DateTime, null: false
      column :last_used_at, DateTime
    end

    create_table :challenges do
      column :id, String, primary_key: true
      column :challenge, String, null: false # base64
      column :expires_at, DateTime, null: false
      column :used_at, DateTime
    end

    create_table :sessions do
      primary_key :id
      foreign_key :user_id, :users, null: false
      foreign_key :certificate_id, :certificates, null: false
      column :token_digest, String, null: false, unique: true
      column :expires_at, DateTime, null: false
      column :created_at, DateTime, null: false
    end

    # A payment profile: one per CPF or CNPJ the user issues as.
    create_table :profiles do
      primary_key :id
      foreign_key :user_id, :users, null: false
      column :kind, String, null: false # pf or pj
      column :document, String, null: false # CPF or CNPJ
      column :name, String
      column :settings, String, null: false, default: "{}" # JSON
      column :next_invoice_number, Integer, null: false, default: 1
      column :created_at, DateTime, null: false
      unique %i[user_id document]
    end

    create_table :dps_counters do
      foreign_key :profile_id, :profiles, null: false
      column :environment, String, null: false
      column :serie, String, null: false
      column :next_number, Integer, null: false
      primary_key %i[profile_id environment serie]
    end

    create_table :templates do
      primary_key :id
      foreign_key :profile_id, :profiles, null: false
      column :kind, String, null: false # invoice or dps
      column :name, String, null: false
      column :body, String, null: false # JSON
      column :created_at, DateTime, null: false
    end

    create_table :invoices do
      primary_key :id
      foreign_key :profile_id, :profiles, null: false
      column :number, Integer, null: false
      column :params, String, null: false # JSON
      column :pdf, File, null: false
      column :created_at, DateTime, null: false
      unique %i[profile_id number]
    end

    create_table :dps do
      primary_key :id
      foreign_key :profile_id, :profiles, null: false
      foreign_key :invoice_id, :invoices, null: false
      column :environment, String, null: false
      column :serie, String, null: false
      column :n_dps, Integer, null: false
      column :dps_id, String, null: false, unique: true
      # built -> issued | rejected | unknown; unknown -> issued | rejected
      column :state, String, null: false
      column :unsigned_xml, String, null: false
      column :signed_xml, String
      column :nfse_xml, String
      column :chave_acesso, String
      column :messages, String # JSON
      column :pdf, File
      column :created_at, DateTime, null: false
      column :updated_at, DateTime, null: false
      unique %i[profile_id environment serie n_dps]
    end
  end
end
