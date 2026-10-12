# A plain module rather than a concern, so Failure resolves through every
# module that includes it.
module RendersFailures
  Failure = Data.define(:status, :code, :message)

  private

  def render_failure(failure, headers: {})
    headers.each { |name, value| response.set_header(name, value) }
    render status: failure.status, json: { errors: [{ code: failure.code, message: failure.message }] }
  end

  # @param record [ActiveRecord::Base]
  def render_invalid(record)
    errors = record.errors.map do |error|
      field = error.attribute.to_s unless error.attribute == :base
      { code: error.type.to_s, field:, message: error.full_message }.compact
    end

    render status: :unprocessable_content, json: { errors: }
  end
end
