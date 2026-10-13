require "net/http"

# Fetches an image from a merchant-supplied URL without reaching private networks.
class Product::Image::Download
  MAX_REDIRECTS = 3
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15
  # Seconds for the whole download, redirects included.
  TOTAL_TIMEOUT = 60
  # Loopback, private, link-local (cloud metadata), CGNAT, multicast, reserved, and their IPv6 forms.
  REFUSED = [
    "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24",
    "192.168.0.0/16", "198.18.0.0/15", "224.0.0.0/4", "240.0.0.0/4", "::/128", "::1/128", "64:ff9b::/96",
    "64:ff9b:1::/48", "2001::/32", "2002::/16", "fc00::/7", "fe80::/10", "ff00::/8"
  ].map { |range| IPAddr.new(range) }.freeze
  NETWORK_ERRORS = [
    SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError,
    IOError, Net::HTTPHeaderSyntaxError, Zlib::Error
  ].freeze

  class Error < StandardError
    attr_reader :code

    # @param code [String]
    # @param message [String]
    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  # @param url [String]
  # @yield [Tempfile] the body, rewound
  def self.open(url, &) = new.open(url, &)

  # @param address [String]
  def self.public?(address)
    ip = IPAddr.new(address)
    ip = ip.native if ip.ipv6? && (ip.ipv4_mapped? || ip.ipv4_compat?)
    REFUSED.none? { |range| range.family == ip.family && range.include?(ip) }
  end

  # @param url [String]
  # @yield [Tempfile]
  def open(url)
    @deadline = now + TOTAL_TIMEOUT
    file = download(parse(url))
    yield file
  ensure
    file&.close!
  end

  private

  def download(uri)
    (MAX_REDIRECTS + 1).times do
      result = hop(uri)
      return result if result.is_a?(Tempfile)

      uri = parse(URI.join(uri.to_s, Product::Image.encode_url(result)).to_s)
    end
    raise Error.new("image_unreachable", "The image URL redirects more than #{MAX_REDIRECTS} times.")
  rescue URI::Error
    raise Error.new("image_unreachable", "The image URL redirects to an address that is not valid.")
  end

  # Read timeouts apply per read, so a host that drips bytes needs an overall limit across lookup, headers and body.
  def hop(uri)
    remaining = @deadline - now
    timed_out if remaining <= 0
    Timeout.timeout(remaining) { request(uri) }
  rescue Timeout::Error
    timed_out
  end

  # @return [Tempfile, String] the body, or a redirect's location
  def request(uri)
    ip = address(uri.hostname)
    # No proxy, because a proxy would connect to the hostname and skip the address check.
    http = Net::HTTP.new(uri.hostname, uri.port, nil)
    http.ipaddr = ip
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.start do
      http.request(Net::HTTP::Get.new(uri)) do |response|
        if response.is_a?(Net::HTTPRedirection)
          return response["location"] || unreachable("a redirect with no location")
        end
        return body(response) if response.is_a?(Net::HTTPSuccess)

        unreachable("status #{response.code}")
      end
    end
  rescue *NETWORK_ERRORS => error
    unreachable(error.message)
  end

  # Every answer must be public, so a mixed DNS answer cannot pick a private one later.
  def address(host)
    addresses = Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address).uniq
    return addresses.first if addresses.any? && addresses.all? { |ip| self.class.public?(ip) }

    raise Error.new("image_address_refused", "The image host resolves to an address that is not public.")
  end

  def body(response)
    if response.content_length.to_i > Product::Image::MAX_BYTES
      unreachable("it is larger than #{Product::Image::MAX_BYTES / 1.megabyte} MB")
    end

    file = Tempfile.new(binmode: true)
    response.read_body do |chunk|
      file.write(chunk)
      break if file.size > Product::Image::MAX_BYTES
    end
    file.rewind
    file
  end

  def parse(url)
    uri = URI.parse(Product::Image.encode_url(url))
    return uri if uri.is_a?(URI::HTTP) && uri.hostname.present? && uri.userinfo.nil?

    raise Error.new("image_unreachable", "The image URL must be an http or https address without credentials.")
  rescue URI::InvalidURIError
    raise Error.new("image_unreachable", "The image URL is not valid.")
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def timed_out = unreachable("it took longer than #{TOTAL_TIMEOUT} seconds")

  def unreachable(reason)
    raise Error.new("image_unreachable", "The image could not be downloaded: #{reason}.")
  end
end
