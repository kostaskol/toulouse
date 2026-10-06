namespace :platform do
  namespace :admins do
    # Hidden only on a terminal, so a password can still be piped in.
    read_secret = lambda do |label|
      print label
      next $stdin.gets.to_s.chomp unless $stdin.tty?

      require "io/console"
      $stdin.noecho(&:gets).to_s.chomp.tap { puts }
    end

    desc "Create a platform admin, or reset one's password and authenticator and sign them out"
    task create: :environment do
      print "Email: "
      email = $stdin.gets.to_s.strip
      password = read_secret.call("Password: ")
      abort "Passwords do not match." unless password == read_secret.call("Confirm password: ")

      admin = ApplicationRecord.connected_to(role: :platform) { Platform::Admin.provision(email:, password:) }

      puts "Add this to an authenticator app. It replaces any earlier one for #{admin.email}.",
           "Secret: #{admin.otp_secret}", "URI: #{admin.provisioning_uri}"
    end

    desc "Print a platform admin's current authenticator code. EMAIL=... Development only"
    task code: :environment do
      # Anyone who can run this could rerun create, but a printed second factor
      # has no place outside a local machine.
      abort "Prints a live second factor, so it runs in development and test only." unless Rails.env.local?

      admin = ApplicationRecord.connected_to(role: :platform) { Platform::Admin.find_by!(email: ENV.fetch("EMAIL")) }
      puts ROTP::TOTP.new(admin.otp_secret).now
    end
  end
end
