# No storefront endpoint writes as the signed-in shopper yet.
class ShopperProbeController < V1::Storefront::BaseController
  def show = head(:ok)
  def update = head(:ok)
end
