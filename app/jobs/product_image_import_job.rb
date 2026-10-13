class ProductImageImportJob < ApplicationJob
  # Solid Queue runs lower numbers first, so sign-in codes and mail never wait behind an import.
  queue_with_priority 10

  # Fetches one image, then queues the rest, so images keep the file's order.
  #
  # @param entry [Product::Import::Entry]
  # @param urls [Array<String>] the URLs still to fetch, in display order
  def perform(entry, urls)
    url, *rest = urls
    store(entry, url)
    Product::Import.update_counters(entry.product_import_id, images_pending: -1)
    self.class.perform_later(entry, rest) if rest.any?
  end

  private

  def store(entry, url)
    Product::Image::Download.open(url) { |file| entry.product.add_image!(file) }
  rescue Product::Image::Download::Error => error
    entry.add_image_error!(code: error.code, message: error.message, url:)
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.each do |detail|
      entry.add_image_error!(code: detail.type.to_s, message: detail.full_message, url:)
    end
  rescue StandardError => error
    Rails.error.report(error)
    entry.add_image_error!(code: "image_failed", message: "The image could not be stored.", url:)
  end
end
