class AddImpersonatorToShopperHandoffs < ActiveRecord::Migration[8.1]
  # Set when a platform admin views a storefront as a shopper. The session it
  # opens is read-only.
  def change
    add_reference :shopper_handoffs, :impersonator, type: :uuid, index: false,
                                                    foreign_key: { to_table: "platform.admins" }
    add_reference :shopper_sessions, :impersonator, type: :uuid, index: false,
                                                    foreign_key: { to_table: "platform.admins" }
  end
end
