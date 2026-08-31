require "digest"
require "openssl"
require "securerandom"

module AskJared
  class TokenService
    TokenAlreadyClaimed = Class.new(StandardError)
    TOKEN_BYTES = 32
    CLAIM_LIFETIME = 90.days

    def initialize(secret: Rails.application.secret_key_base)
      @secret = secret
    end

    def mint!(expires_at: nil)
      raw_token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
      token = AskToken.create!(
        token_digest: digest(raw_token),
        token_prefix: raw_token.first(8),
        status: "available",
        expires_at: expires_at
      )
      [ token, raw_token ]
    end

    def resolve(raw_token)
      return if raw_token.blank?

      AskToken.find_by(token_digest: digest(raw_token))&.then do |token|
        token if token.status.in?(%w[available claimed submitted]) && !token.expires_at&.past?
      end
    end

    def recruiter_accessible?(token)
      token.present? && token.opportunity.present? && token.status.in?(%w[claimed submitted]) && !token.expires_at&.past?
    end

    def claim!(raw_token:, external_id:, company:, role_title:, tracker_source: nil)
      token = resolve(raw_token)
      raise ActiveRecord::RecordNotFound, "Ask token is invalid or unavailable" unless token

      Opportunity.transaction do
        opportunity = Opportunity.create_or_find_by!(external_id: external_id) do |record|
          record.company = company
          record.role_title = role_title
          record.tracker_source = tracker_source
          record.application_state = "ready"
        end
        token.with_lock do
          if token.opportunity_id && token.opportunity_id != opportunity.id
            raise TokenAlreadyClaimed, "Ask token is already claimed"
          end

          token.update!(
            opportunity: opportunity,
            claim_key: external_id,
            status: "claimed",
            claimed_at: token.claimed_at || Time.current,
            expires_at: token.expires_at || CLAIM_LIFETIME.from_now
          )
        end
        opportunity
      end
    end

    def digest(raw_token)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("SHA256"), @secret, raw_token)
    end
  end
end
