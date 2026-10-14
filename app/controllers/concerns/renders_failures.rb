# A plain module rather than a concern, so Failure resolves through every
# module that includes it.
module RendersFailures
  Failure = Data.define(:status, :code, :message)

  private

  # @param failure [Failure]
  # @param headers [Hash{String => String}]
  # @param field [String, nil] the request parameter the failure is about
  def render_failure(failure, headers: {}, field: nil)
    headers.each { |name, value| response.set_header(name, value) }
    render status: failure.status, json: { errors: [{ code: failure.code, field:, message: failure.message }.compact] }
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
