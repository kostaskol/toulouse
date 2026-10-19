module Admin
  class CategoriesController < BaseController
    allow_any_staff

    FAILURES = {
      category_has_children: Failure.new(
        status: :unprocessable_content,
        code: "category_has_children",
        message: "The category has categories below it. Move or remove them first."
      ),
      category_has_products: Failure.new(
        status: :unprocessable_content,
        code: "category_has_products",
        message: "The category has products. Move them to another category first."
      )
    }.freeze

    def index
      render json: { categories: tree(Category.by_parent) }
    end

    def create
      category = Category.create!(category_params)
      render status: :created, json: { category: category_json(category) }
    end

    def update
      category = Category.find(params[:id])
      category.update!(category_params)
      render json: { category: category_json(category) }
    end

    def destroy
      category = Category.find(params[:id])
      return head :no_content if category.destroy

      render_failure(FAILURES.fetch(category.children.exists? ? :category_has_children : :category_has_products))
    end

    private

    def category_params = params.permit(:name, :slug, :parent_id, :position)

    def category_json(category)
      category.slice(:id, :name, :slug, :parent_id, :position)
    end

    def tree(by_parent, parent_id = nil)
      by_parent.fetch(parent_id, []).map do |category|
        category_json(category).merge(children: tree(by_parent, category.id))
      end
    end
  end
end
