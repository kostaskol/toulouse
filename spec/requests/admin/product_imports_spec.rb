require "rails_helper"

RSpec.describe "Tenant admin product imports", type: :request do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:staff_session) { create(:staff_session, tenant:) }
  let(:headers) { staff_cookie(staff_session) }
  let(:rows) do
    [
      { "handle" => "first", "title" => "First", "price" => "1" },
      { "handle" => "second", "title" => "Second", "price" => "" }
    ]
  end

  def upload(text = import_csv(rows), dry_run: false, content_type: "text/csv")
    query = "?dry_run=#{dry_run}" unless dry_run.nil?
    post "/admin/product_imports#{query}", params: text, headers: headers.merge("CONTENT_TYPE" => content_type)
  end

  def import_id = response.parsed_body.dig("product_import", "id")

  describe "POST /admin/product_imports" do
    it "queues the import" do
      upload

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["product_import"]).to include("status" => "queued", "dry_run" => false)
    end

    it "rehearses when dry_run is absent" do
      upload(dry_run: nil)

      expect(response.parsed_body["product_import"]).to include("dry_run" => true)
    end

    it "refuses a body that is not CSV" do
      upload(content_type: "text/plain")

      expect_failure(Admin::ProductImportsController::FAILURES.fetch(:unsupported_media_type))
    end

    it "answers a file-level error at once" do
      upload(import_csv(rows.map { |row| row.merge("prcie" => "1") }))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"])
        .to contain_exactly(include("code" => "unknown_columns", "columns" => ["prcie"]))
    end

    it "refuses a second import while one is active" do
      upload
      upload

      expect_failure(Admin::ProductImportsController::FAILURES.fetch(:import_in_progress))
    end
  end

  describe "GET /admin/product_imports/:id" do
    it "answers the summary once the import has run" do
      upload
      perform_enqueued_jobs
      get "/admin/product_imports/#{import_id}", headers:, as: :json

      expect(response.parsed_body.dig("product_import", "summary", "results"))
        .to eq("created" => 1, "failed" => 1)
    end
  end

  describe "GET /admin/product_imports" do
    it "lists imports newest first" do
      upload
      perform_enqueued_jobs
      first = import_id
      upload
      get "/admin/product_imports", headers:, as: :json

      expect(response.parsed_body["product_imports"].pluck("id").last).to eq(first)
    end
  end

  describe "GET /admin/product_imports/:id/entries" do
    before do
      upload
      perform_enqueued_jobs
    end

    it "lists entries in file order" do
      get "/admin/product_imports/#{import_id}/entries", headers:, as: :json

      expect(response.parsed_body["entries"].pluck("handle")).to eq(["first", "second"])
    end

    it "pages in file order" do
      id = import_id
      get "/admin/product_imports/#{id}/entries?limit=1", headers:, as: :json
      cursor = response.parsed_body.dig("meta", "next_cursor")
      get "/admin/product_imports/#{id}/entries?limit=1&after=#{cursor}", headers:, as: :json

      expect(response.parsed_body["entries"].pluck("handle")).to eq(["second"])
    end

    it "filters by result" do
      get "/admin/product_imports/#{import_id}/entries?result=failed", headers:, as: :json

      entry = response.parsed_body["entries"].sole
      expect(entry).to include("handle" => "second", "rows" => [3])
      expect(entry["errors"]).to contain_exactly(include("code" => "blank", "field" => "price"))
    end

    it "filters by warning code" do
      rows.first["title"] = "Changed"
      upload
      perform_enqueued_jobs
      get "/admin/product_imports/#{import_id}/entries?warning=product_cell_ignored", headers:, as: :json

      expect(response.parsed_body["entries"].pluck("handle")).to eq(["first"])
    end
  end
end
