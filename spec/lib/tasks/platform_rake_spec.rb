require "rails_helper"
require "rake"

RSpec.describe "platform rake tasks", :platform do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("platform:admins:create")
  end

  def run(name, stdin: "")
    original = $stdin
    $stdin = StringIO.new(stdin)
    Rake::Task[name].reenable
    Rake::Task[name].invoke
  ensure
    $stdin = original
  end

  describe "platform:admins:create" do
    let(:email) { build(:platform_admin).email }
    let(:password) { SecureRandom.alphanumeric(16) }

    it "creates the admin and prints the authenticator URI" do
      expect { run("platform:admins:create", stdin: "#{email}\n#{password}\n#{password}\n") }
        .to output(%r{otpauth://totp/}).to_stdout

      expect(Platform::Admin.find_by(email:).authenticate(password)).to be_truthy
    end

    it "resets an existing admin" do
      admin = create(:platform_admin)
      create(:platform_admin_session, admin:)

      expect { run("platform:admins:create", stdin: "#{admin.email}\n#{password}\n#{password}\n") }
        .to output.to_stdout

      expect(admin.reload.authenticate(password)).to be_truthy
      expect(admin.sessions).to be_empty
    end

    it "refuses passwords that do not match" do
      expect { run("platform:admins:create", stdin: "#{email}\n#{password}\nmismatch-#{password}\n") }
        .to raise_error(SystemExit).and output.to_stdout.and output(/do not match/).to_stderr

      expect(Platform::Admin.find_by(email:)).to be_nil
    end
  end

  describe "platform:admins:code" do
    let(:admin) { create(:platform_admin) }

    around do |example|
      original = ENV.fetch("EMAIL", nil)
      ENV["EMAIL"] = admin.email
      example.run
    ensure
      ENV["EMAIL"] = original
    end

    it "prints the admin's current code" do
      expect { run("platform:admins:code") }.to output("#{ROTP::TOTP.new(admin.otp_secret).now}\n").to_stdout
    end

    it "refuses to run in production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

      expect { run("platform:admins:code") }.to raise_error(SystemExit).and output(/development/).to_stderr
    end
  end
end
