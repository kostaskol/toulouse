require "rails_helper"

RSpec.describe "Account email limit", type: :request do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:api_key) { create(:tenant_api_key, tenant:) }
  let(:email) { build(:shopper).email }
  let(:shopper_ip) { random_ip(Socket::AF_INET) }

  before do
    as_tenant(tenant) { tenant.setting.update!(sender_email: "orders@shop.example.com") }
    # Staff mail links to admin on the primary domain.
    create(:tenant_domain, tenant:, is_primary: true)
    ActionMailer::Base.deliveries.clear
  end

  def random_ip(family)
    bits = family == Socket::AF_INET ? 32 : 128
    IPAddr.new(SecureRandom.random_number(2**bits), family)
  end

  def storefront_headers(ip: shopper_ip, key: api_key)
    { Tenancy::RequiresTenant::HEADER => key.token, V1::Storefront::BaseController::SHOPPER_IP_HEADER => ip.to_s }
  end

  def request_signup(email: self.email, headers: storefront_headers)
    post "/v1/storefront/signup", params: { email: }, headers:, as: :json
    perform_enqueued_jobs
  end

  def request_shopper_reset(email: self.email, headers: storefront_headers)
    post "/v1/storefront/password_reset", params: { email: }, headers:, as: :json
    perform_enqueued_jobs
  end

  def request_staff_reset(email:, slug: tenant.slug, ip: shopper_ip)
    post "/admin/password_reset", params: { slug:, email: }, env: { "REMOTE_ADDR" => ip.to_s }, as: :json
    perform_enqueued_jobs
  end

  def mailed_count = ActionMailer::Base.deliveries.size

  describe "per email" do
    it "stops mailing an email past the limit and still accepts" do
      (LimitsAccountEmail::EMAIL_LIMIT + 1).times { request_signup }

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
      expect(mailed_count).to eq(LimitsAccountEmail::EMAIL_LIMIT)
    end

    it "counts across storefront endpoints" do
      LimitsAccountEmail::EMAIL_LIMIT.times { request_signup }
      create(:shopper, tenant:, email:)

      request_shopper_reset

      expect(mailed_count).to eq(LimitsAccountEmail::EMAIL_LIMIT)
    end

    it "counts staff reset and storefront reset together" do
      staff = create(:shopper, :linked_to_staff, tenant:).staff
      LimitsAccountEmail::EMAIL_LIMIT.times { request_staff_reset(email: staff.email) }

      request_shopper_reset(email: staff.email)

      expect(mailed_count).to eq(LimitsAccountEmail::EMAIL_LIMIT)
    end

    it "counts the email regardless of case and padding" do
      LimitsAccountEmail::EMAIL_LIMIT.times { request_signup }
      request_signup(email: " #{email.upcase} ")

      expect(mailed_count).to eq(LimitsAccountEmail::EMAIL_LIMIT)
    end

    it "answers a taken email alike once limited" do
      create(:shopper, tenant:, email:)
      LimitsAccountEmail::EMAIL_LIMIT.times { request_signup }

      request_signup

      expect(response).to have_http_status(:accepted)
    end

    it "mails again once the window passes" do
      LimitsAccountEmail::EMAIL_LIMIT.times { request_signup }

      travel(LimitsAccountEmail::EMAIL_WINDOW + 1.second) { request_signup }

      expect(mailed_count).to eq(LimitsAccountEmail::EMAIL_LIMIT + 1)
    end

    it "counts each store apart" do
      other_key = create(:tenant_api_key, tenant: create(:tenant))
      as_tenant(other_key.tenant) { other_key.tenant.setting.update!(sender_email: "orders@shop.example.com") }
      LimitsAccountEmail::EMAIL_LIMIT.times { request_signup }

      request_signup(headers: storefront_headers(key: other_key))

      expect(mailed_count).to eq(LimitsAccountEmail::EMAIL_LIMIT + 1)
    end

    it "limits staff reset by store slug" do
      staff = create(:staff, tenant:)
      LimitsAccountEmail::EMAIL_LIMIT.times { request_staff_reset(email: staff.email) }

      request_staff_reset(email: staff.email)

      expect(response).to have_http_status(:accepted)
      expect(mailed_count).to eq(LimitsAccountEmail::EMAIL_LIMIT)
    end
  end

  describe "per IP" do
    def exhaust_ip_limit(headers: storefront_headers)
      LimitsAccountEmail::IP_LIMIT.times { |n| request_signup(email: "#{n}-#{email}", headers:) }
      ActionMailer::Base.deliveries.clear
    end

    it "stops mailing any email from an IP past the limit" do
      exhaust_ip_limit

      request_signup

      expect(response).to have_http_status(:accepted)
      expect(mailed_count).to eq(0)
    end

    it "hides a taken email once limited" do
      create(:shopper, tenant:, email:)
      exhaust_ip_limit

      request_signup

      expect(response).to have_http_status(:accepted)
    end

    it "keys on the shopper IP the BFF sends" do
      exhaust_ip_limit

      request_signup(headers: storefront_headers(ip: random_ip(Socket::AF_INET)))

      expect(mailed_count).to eq(1)
    end

    it "keys an IPv6 shopper on their /64" do
      network = random_ip(Socket::AF_INET6).mask(64)
      exhaust_ip_limit(headers: storefront_headers(ip: network | 1))

      request_signup(headers: storefront_headers(ip: network | 2))

      expect(mailed_count).to eq(0)
    end

    it "keys an IPv4-mapped shopper on their IPv4 address" do
      exhaust_ip_limit(headers: storefront_headers(ip: random_ip(Socket::AF_INET).ipv4_mapped))

      request_signup(headers: storefront_headers(ip: random_ip(Socket::AF_INET).ipv4_mapped))

      expect(mailed_count).to eq(1)
    end

    it "falls back to the connecting IP when the header is malformed" do
      exhaust_ip_limit(headers: storefront_headers(ip: "not an address"))

      request_signup(headers: storefront_headers(ip: ""))

      expect(mailed_count).to eq(0)
    end

    it "ignores the shopper IP header on tenant admin" do
      staff = create(:staff, tenant:)
      LimitsAccountEmail::IP_LIMIT.times { |n| request_staff_reset(email: "#{n}-#{staff.email}") }

      other_ip = random_ip(Socket::AF_INET).to_s
      post "/admin/password_reset", params: { slug: tenant.slug, email: staff.email },
                                    headers: { V1::Storefront::BaseController::SHOPPER_IP_HEADER => other_ip },
                                    env: { "REMOTE_ADDR" => shopper_ip.to_s }, as: :json
      perform_enqueued_jobs

      expect(mailed_count).to eq(0)
    end
  end
end
