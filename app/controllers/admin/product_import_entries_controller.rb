module Admin
  class ProductImportEntriesController < BaseController
    include Paginates

    allow_any_staff

    def index
      import = Product::Import.without_file.find(params[:product_import_id])
      entries, next_cursor = paginate(filtered(import.entries), order: :asc)
      render json: { entries: entries.map { |entry| entry_json(entry) }, meta: { next_cursor: } }
    end

    private

    def filtered(scope)
      scope = scope.where(result: params[:result]) if params[:result]
      scope = scope.where("warnings @> ?::jsonb", [{ code: params[:warning] }].to_json) if params[:warning]
      return scope unless ActiveModel::Type::Boolean.new.cast(params[:image_errors])

      scope.where("jsonb_array_length(image_errors) > 0")
    end

    def entry_json(entry)
      entry.slice(
        :id, :position, :handle, :rows, :result, :product_id, :warnings, :image_errors, :created_brands,
        :created_categories
      ).merge(errors: entry.error_details)
    end
  end
end
