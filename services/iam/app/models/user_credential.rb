# frozen_string_literal: true

class UserCredential < Iam::ApplicationRecord
  belongs_to :user
  belongs_to :credential

  before_validation :create_credential, unless: :credential
end
