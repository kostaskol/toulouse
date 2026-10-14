module Admin
  class SpecificationsController < BaseController
    include CatalogJson

    allow_any_staff

    def index
      specifications = Specification.order(:position, :id)
      render json: { specifications: specifications.map { |specification| specification_json(specification) } }
    end

    def create
      specification = Specification.create!(specification_params)
      render status: :created, json: { specification: specification_json(specification) }
    end

    def update
      specification = Specification.find(params[:id])
      specification.update!(specification_params)
      render json: { specification: specification_json(specification) }
    end

    # Strips the spec from every product and variant that states it.
    def destroy
      Specification.find(params[:id]).destroy!
      head :no_content
    end

    private

    def specification_params = params.permit(:name, :position, :facet, :mode)
  end
end
