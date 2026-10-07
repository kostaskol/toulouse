# A plain module rather than a concern, so Failure resolves through every
# module that includes it.
module RendersFailures
  Failure = Data.define(:status, :code, :message)

  private

  def render_failure(failure, headers: {})
    headers.each { |name, value| response.set_header(name, value) }
    render status: failure.status, json: { errors: [{ code: failure.code, message: failure.message }] }
  end
end
