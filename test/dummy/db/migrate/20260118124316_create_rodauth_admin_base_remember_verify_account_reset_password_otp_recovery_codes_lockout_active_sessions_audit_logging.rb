class CreateRodauthAdminBaseRememberVerifyAccountResetPasswordOtpRecoveryCodesLockoutActiveSessionsAuditLogging < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :admins do |t|
      t.integer :status, null: false, default: 1
      t.string :email, null: false
      t.index :email, unique: true, where: "status IN (1, 2)"
      t.string :password_hash
    end

    # Used by the remember me feature
    create_table :admin_remember_keys, id: false do |t|
      t.bigint :id, primary_key: true
      t.foreign_key :admins, column: :id
      t.string :key, null: false
      t.datetime :deadline, null: false
    end

    # Used by the account verification feature
    create_table :admin_verification_keys, id: false do |t|
      t.bigint :id, primary_key: true
      t.foreign_key :admins, column: :id
      t.string :key, null: false
      t.datetime :requested_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :email_last_sent, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    # Used by the password reset feature
    create_table :admin_password_reset_keys, id: false do |t|
      t.bigint :id, primary_key: true
      t.foreign_key :admins, column: :id
      t.string :key, null: false
      t.datetime :deadline, null: false
      t.datetime :email_last_sent, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    # Used by the otp feature
    create_table :admin_otp_keys, id: false do |t|
      t.bigint :id, primary_key: true
      t.foreign_key :admins, column: :id
      t.string :key, null: false
      t.integer :num_failures, null: false, default: 0
      t.datetime :last_use, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    # Used by the recovery codes feature
    create_table :admin_recovery_codes, primary_key: [:id, :code] do |t|
      t.bigint :id
      t.foreign_key :admins, column: :id
      t.string :code
    end

    # Used by the lockout feature
    create_table :admin_login_failures, id: false do |t|
      t.bigint :id, primary_key: true
      t.foreign_key :admins, column: :id
      t.integer :number, null: false, default: 1
    end
    create_table :admin_lockouts, id: false do |t|
      t.bigint :id, primary_key: true
      t.foreign_key :admins, column: :id
      t.string :key, null: false
      t.datetime :deadline, null: false
      t.datetime :email_last_sent
    end

    # Used by the active sessions feature
    create_table :admin_active_session_keys, primary_key: [:admin_id, :session_id] do |t|
      t.references :admin, foreign_key: true
      t.string :session_id
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :last_use, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    # Used by the audit logging feature
    create_table :admin_authentication_audit_logs do |t|
      t.references :admin, foreign_key: true, null: false
      t.datetime :at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.text :message, null: false
      t.json :metadata
      t.index [:admin_id, :at], name: "audit_admin_admin_id_at_idx"
      t.index :at, name: "audit_admin_at_idx"
    end
  end
end
