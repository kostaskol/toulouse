require "rails_helper"

RSpec.describe "Credential storage" do
  it "encrypts and decrypts with the configured keys" do
    secret = SecureRandom.hex
    ciphertext = ActiveRecord::Encryption.encryptor.encrypt(secret)

    expect(ciphertext).not_to include(secret)
    expect(ActiveRecord::Encryption.encryptor.decrypt(ciphertext)).to eq(secret)
  end

  it "hashes passwords with has_secure_password" do
    account_class = Class.new do
      include ActiveModel::SecurePassword

      attr_accessor :password_digest

      has_secure_password validations: false
    end
    password = SecureRandom.alphanumeric(16)
    account = account_class.new.tap { |a| a.password = password }

    expect(account.password_digest).not_to include(password)
    expect(account.authenticate(password)).to eq(account)
  end
end
