require "rails_helper"

RSpec.describe AuthorizesStaff do
  def controller_class(&) = Class.new(V1::Admin::BaseController, &)

  it "applies a declaration without only to every action" do
    controller = controller_class { requires_permission :manage_staff }

    expect(controller.staff_authorization(:index)).to eq(:manage_staff)
    expect(controller.staff_authorization(:create)).to eq(:manage_staff)
  end

  it "lets a per-action declaration override the controller-wide one" do
    controller = controller_class do
      requires_permission :manage_staff
      allow_any_staff only: :index
    end

    expect(controller.staff_authorization(:index)).to eq(described_class::ANY_STAFF)
    expect(controller.staff_authorization(:create)).to eq(:manage_staff)
  end

  it "leaves an undeclared action without an authorization" do
    controller = controller_class { allow_any_staff only: :index }

    expect(controller.staff_authorization(:create)).to be_nil
  end

  it "rejects a permission no role has" do
    expect { controller_class { requires_permission :no_such_permission } }
      .to raise_error(ArgumentError, /no_such_permission/)
  end

  it "keeps a subclass's declarations off its parent" do
    parent = controller_class { allow_any_staff only: :index }
    child = Class.new(parent) { requires_permission :manage_staff, only: :create }

    expect(child.staff_authorization(:create)).to eq(:manage_staff)
    expect(parent.staff_authorization(:create)).to be_nil
  end
end
