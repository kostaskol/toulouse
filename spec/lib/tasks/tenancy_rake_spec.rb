require "rails_helper"
require "open3"

RSpec.describe "db:load_config" do
  # A subprocess, since switching this process to the owner would outlive the
  # example.
  it "keeps database tasks connected as the owner once models load" do
    script = <<~RUBY
      Rails.application.load_tasks
      Rake::Task["db:load_config"].invoke
      puts Tenant.lease_connection.select_value("SELECT current_user")
    RUBY
    output, status = Open3.capture2e({ "RAILS_ENV" => "test" }, "bin/rails", "runner", script)
    owner = ActiveRecord::Base.configurations.configs_for(env_name: "test", name: "owner")

    expect(status).to be_success, output
    expect(output.lines.last.chomp).to eq(owner.configuration_hash[:username])
  end
end
