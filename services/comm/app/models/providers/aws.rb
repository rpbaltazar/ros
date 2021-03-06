# frozen_string_literal: true

module Providers
  class Aws < Provider
    alias_attribute :access_key_id, :credential_1
    alias_attribute :secret_access_key, :credential_2

    def self.services; %w(sms) end

    def client
      @client ||= ::Aws::SNS::Client.new(
        region: 'ap-southeast-1',
        access_key_id: access_key_id,
        secret_access_key: secret_access_key) if x_access_key_id and x_secret_access_key
    end

    def x_access_key_id
      access_key_id || current_tenant.platform_aws_enabled ? ENV['AWS_ACCESS_KEY_ID'] : nil
    end

    def x_secret_access_key
      secret_access_key || current_tenant.platform_aws_enabled ? ENV['AWS_SECRET_ACCESS_KEY'] : nil
    end

    # TODO: Get from provider
    def from; 'Prudential' end

    # TODO: toggle sending on and off
    def sms(message)
      return unless Settings.active
      message.update(from: from)
      client.set_sms_attributes({ attributes: { 'DefaultSenderID' => from } })
      res = client.publish(phone_number: message.to, message: message.body)
      p message
    # rescue
      # Rails.logger.warn('No AWS client configured for tenant.account_id') and return if client.nil?
    end
  end
end
