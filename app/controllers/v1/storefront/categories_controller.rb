module V1
  module Storefront
    class CategoriesController < BaseController
      def index
        render json: { categories: tree(Category.by_parent) }
      end

      private

      def tree(by_parent, parent_id = nil)
        by_parent.fetch(parent_id, []).map do |category|
          category.slice(:id, :name, :slug).merge(children: tree(by_parent, category.id))
        end
      end
    end
  end
end
