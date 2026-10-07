class Platform::SessionsController < Platform::BaseController
  skip_before_action :require_admin_session, only: [:new, :create]

  def new
  end

  def create
    result = Platform::Login.call(email: params[:email], password: params[:password], code: params[:code])

    if result.failure
      @failed = true
      return render(:new, status: :unauthorized)
    end

    # A new CSRF token for the signed-in session.
    reset_session
    write_session_cookie(result.session)
    redirect_to platform_root_path
  end

  def destroy
    admin_session.destroy!
    reset_session
    clear_session_cookie
    redirect_to new_platform_session_path
  end
end
