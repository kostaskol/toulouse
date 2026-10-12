# Cursor pagination over UUIDv7 ids, newest first. Ids sort by creation, so a
# page stays stable while new rows arrive.
module Paginates
  extend ActiveSupport::Concern
  include RendersFailures

  DEFAULT_LIMIT = 25
  MAX_LIMIT = 100
  UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  FAILURES = {
    invalid_cursor: Failure.new(
      status: :unprocessable_content,
      code: "invalid_cursor",
      message: "The after parameter must be a next_cursor from an earlier page."
    )
  }.freeze

  class InvalidCursor < StandardError; end

  included do
    rescue_from(InvalidCursor) { render_failure(Paginates::FAILURES.fetch(:invalid_cursor)) }
  end

  private

  # @param scope [ActiveRecord::Relation]
  # @return [Array(Array<ActiveRecord::Base>, String, nil)] the page and the cursor for the next one
  def paginate(scope)
    after = params[:after]
    raise InvalidCursor if after && !UUID.match?(after.to_s)

    limit = Integer(params[:limit], exception: false)&.clamp(1, MAX_LIMIT) || DEFAULT_LIMIT
    scope = scope.where(id: ...after) if after
    # One row past the page tells whether another page exists.
    records = scope.reorder(id: :desc).limit(limit + 1).to_a

    [records.first(limit), (records[limit - 1].id if records.size > limit)]
  end
end
