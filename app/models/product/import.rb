class Product::Import < ApplicationRecord
  include Tenancy::Scoped

  FAILED = {
    code: "import_failed", message: "The import stopped on an unexpected error. Upload the file again to finish it."
  }.freeze
  # A hard-killed worker leaves its import active, which blocks the tenant from uploading again.
  STALE_AFTER = 30.minutes

  belongs_to :staff, optional: true
  has_many :entries, foreign_key: :product_import_id, inverse_of: :import, dependent: :delete_all

  enum :status, { queued: 0, running: 1, done: 2, failed: 3 }, validate: true

  scope :without_file, -> { select(column_names - ["file"]) }

  # Checks the file, stores it and queues the run.
  #
  # @param staff [Staff]
  # @param text [String]
  # @param dry_run [Boolean]
  # @return [Product::Import]
  def self.start!(staff:, text:, dry_run:)
    active = where(status: [:queued, :running])
    active.where(updated_at: ...STALE_AFTER.ago)
          .update_all(status: :failed, error_details: [FAILED], file: nil, finished_at: Time.current)
    # Checked before parsing, so parallel uploads do not each read a whole file only to lose on the index.
    raise ActiveRecord::RecordNotUnique, "An import is already active" if active.exists?

    sheet = Sheet.new(text)
    create!(staff:, dry_run:, file: sheet.text).tap { |import| ProductImportJob.perform_later(import) }
  end

  def run!
    claimed = self.class.where(id:, status: [:queued, :running]).update_all(status: :running, updated_at: Time.current)
    return if claimed.zero?

    PaperTrail.request(whodunnit: staff&.to_global_id&.to_s) { dry_run? ? rehearse : write }
    finish(status: :done)
  rescue StandardError => error
    Rails.error.report(error)
    finish(status: :failed, error_details: [FAILED])
  end

  # @return [Hash] counts per result, products per warning code, and products with image errors
  def summary
    warnings = entries.joins("CROSS JOIN LATERAL jsonb_array_elements(product_import_entries.warnings) AS warning")
                      .group("warning->>'code'").distinct.count(:id)
    {
      results: entries.group(:result).count, warnings:,
      image_errors: entries.where("jsonb_array_length(image_errors) > 0").count
    }
  end

  private

  # Only a running import moves on, so the failure a sweep wrote is never overwritten.
  def finish(**attributes)
    self.class.where(id:, status: :running).update_all(file: nil, finished_at: Time.current, **attributes)
  end

  # @return [Array<Array(Product::Import::Group, Integer)>] each group from start on, with its position
  def groups_from(start) = Sheet.new(file).groups.each_with_index.drop(start)

  # A deploy can kill the worker mid-run. The rerun starts after the last entry it wrote.
  def write
    groups_from(entries.maximum(:position)&.succ || 0).each do |group, position|
      break unless self.class.exists?(id:, status: :running)

      entry = transaction do
        attributes = Writer.new(group).call
        self.class.update_counters(id, images_pending: group.image_urls.size) if attributes[:result] == "created"
        entries.create!(**attributes, position:)
      end
      ProductImageImportJob.perform_later(entry, group.image_urls) if entry.created? && group.image_urls.any?
      touch
    end
  end

  # Savepoints inside one rolled-back transaction, so later products see what earlier ones would create.
  def rehearse
    rows = []
    transaction do
      groups_from(0).each do |group, position|
        rows << Writer.new(group).call.merge(position:, product_id: nil, tenant_id:, product_import_id: id)
      end
      raise ActiveRecord::Rollback
    end
    Entry.insert_all!(rows)
  end
end
