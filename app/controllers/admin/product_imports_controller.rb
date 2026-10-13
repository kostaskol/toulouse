module Admin
  class ProductImportsController < BaseController
    include Paginates

    allow_any_staff

    FAILURES = {
      unsupported_media_type: Failure.new(
        status: :unsupported_media_type,
        code: "unsupported_media_type",
        message: "Send the file as the request body, as text/csv."
      ),
      import_in_progress: Failure.new(
        status: :conflict,
        code: "import_in_progress",
        message: "Another import is still running for this store. Wait for it to finish."
      )
    }.freeze

    # Forms post only url-encoded, multipart or plain text, so a text/csv body needs a preflight and keeps CSRF out.
    skip_before_action :require_json_body!, only: :create
    before_action :require_csv_body!, only: :create

    def index
      imports, next_cursor = paginate(Product::Import.without_file)
      render json: { product_imports: imports.map { |import| import_json(import) }, meta: { next_cursor: } }
    end

    def show
      import = Product::Import.without_file.find(params[:id])
      render json: { product_import: import_json(import).merge(summary: import.summary) }
    end

    def create
      # Reading past the cap lets the size check tell an oversize file from one exactly at the limit.
      text = request.body.read(Product::Import::Sheet::MAX_BYTES + 1).to_s
      # Only an explicit false writes, so a forgotten parameter cannot create products by accident.
      dry_run = ActiveModel::Type::Boolean.new.cast(params[:dry_run]) != false
      import = Product::Import.start!(staff: Current.user, text:, dry_run:)
      render status: :accepted, json: { product_import: import_json(import) }
    rescue Product::Import::Sheet::Error => error
      render_failure(Failure.new(status: :unprocessable_content, code: error.code, message: error.message))
    rescue ActiveRecord::RecordNotUnique
      render_failure(FAILURES.fetch(:import_in_progress))
    end

    private

    def import_json(import)
      import.slice(:id, :status, :dry_run, :images_pending, :created_at, :finished_at)
            .merge(errors: import.error_details)
    end

    def require_csv_body!
      render_failure(FAILURES.fetch(:unsupported_media_type)) unless request.media_type == "text/csv"
    end
  end
end
