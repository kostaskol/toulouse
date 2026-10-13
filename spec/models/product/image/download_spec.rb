require "rails_helper"
require "socket"

RSpec.describe Product::Image::Download do
  # One call per example, so a later stub cannot shadow an earlier host.
  def resolve(hosts)
    allow(Addrinfo).to receive(:getaddrinfo).and_call_original
    hosts.each do |host, address|
      allow(Addrinfo).to receive(:getaddrinfo).with(host, any_args).and_return([Addrinfo.tcp(address, 80)])
    end
  end

  # Only the examples that serve on loopback treat it as public.
  def allow_loopback
    allow(described_class).to receive(:public?).and_wrap_original { |original, ip| ip == "127.0.0.1" || original.(ip) }
  end

  def serve(*responses)
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      responses.each do |response|
        client = server.accept
        client.gets("\r\n\r\n")
        client.write(response)
        client.close
      end
    end
    allow_loopback
    yield server.addr[1]
  ensure
    thread&.kill
    server&.close
  end

  # Sends the head, then one more byte at a time, never finishing.
  def drip(head)
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      client = server.accept
      client.gets("\r\n\r\n")
      client.write(head)
      loop do
        client.write("x")
        sleep 0.05
      end
    end
    allow_loopback
    yield server.addr[1]
  ensure
    thread&.kill
    server&.close
  end

  def ok(body) = "HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"

  def redirect(location) = "HTTP/1.1 302 Found\r\nLocation: #{location}\r\nContent-Length: 0\r\n\r\n"

  def code(url)
    described_class.open(url) { nil }
  rescue described_class::Error => error
    error.code
  end

  ["127.0.0.1", "10.1.2.3", "169.254.169.254", "172.16.0.1", "192.168.1.1", "100.64.0.1", "0.0.0.0",
   "::1", "fe80::1", "fd00::1", "::ffff:127.0.0.1", "64:ff9b::a01:203",
   "64:ff9b:1::a01:203", "2001::1", "2002:7f00:1::"].each do |address|
    it "refuses a host that resolves to #{address}" do
      resolve("images.test" => address)
      allow(Net::HTTP).to receive(:new).and_call_original

      expect(code("http://images.test/a.jpg")).to eq("image_address_refused")
      expect(Net::HTTP).not_to have_received(:new)
    end
  end

  it "refuses a URL that is not http" do
    expect(code("file:///etc/passwd")).to eq("image_unreachable")
  end

  it "refuses credentials in the URL" do
    expect(code("http://user:pass@images.test/a.jpg")).to eq("image_unreachable")
  end

  it "yields the body" do
    resolve("images.test" => "127.0.0.1")
    serve(ok("bytes")) do |port|
      described_class.open("http://images.test:#{port}/a.jpg") { |file| expect(file.read).to eq("bytes") }
    end
  end

  it "follows a redirect to a public host" do
    resolve("images.test" => "127.0.0.1")
    serve(redirect("/b.jpg"), ok("bytes")) do |port|
      described_class.open("http://images.test:#{port}/a.jpg") { |file| expect(file.read).to eq("bytes") }
    end
  end

  it "refuses a redirect to a private host" do
    resolve("images.test" => "127.0.0.1", "internal.test" => "10.0.0.5")
    serve(redirect("http://internal.test/a.jpg")) do |port|
      expect(code("http://images.test:#{port}/a.jpg")).to eq("image_address_refused")
    end
  end

  it "stops after the redirect cap" do
    resolve("images.test" => "127.0.0.1")
    responses = Array.new(described_class::MAX_REDIRECTS + 1) { redirect("/again") }
    serve(*responses) { |port| expect(code("http://images.test:#{port}/a.jpg")).to eq("image_unreachable") }
  end

  it "follows a redirect to a Greek file name" do
    resolve("images.test" => "127.0.0.1")
    serve(redirect("/εικόνα.jpg"), ok("bytes")) do |port|
      described_class.open("http://images.test:#{port}/a.jpg") { |file| expect(file.read).to eq("bytes") }
    end
  end

  it "reports a redirect to an invalid URI as unreachable" do
    resolve("images.test" => "127.0.0.1")
    serve(redirect("http://[bad")) do |port|
      expect(code("http://images.test:#{port}/a.jpg")).to eq("image_unreachable")
    end
  end

  it "refuses a body whose length is over the cap before reading it" do
    stub_const("Product::Image::MAX_BYTES", "byte".bytesize)
    resolve("images.test" => "127.0.0.1")
    serve(ok("bytes")) { |port| expect(code("http://images.test:#{port}/a.jpg")).to eq("image_unreachable") }
  end

  it "gives up on a body that never finishes" do
    stub_const("#{described_class}::TOTAL_TIMEOUT", 0.2)
    resolve("images.test" => "127.0.0.1")
    head = "HTTP/1.1 200 OK\r\nContent-Length: #{Product::Image::MAX_BYTES}\r\n\r\n"
    drip(head) { |port| expect(code("http://images.test:#{port}/a.jpg")).to eq("image_unreachable") }
  end

  it "gives up on headers that never finish" do
    stub_const("#{described_class}::TOTAL_TIMEOUT", 0.2)
    resolve("images.test" => "127.0.0.1")
    drip("HTTP/1.1 200 OK\r\nX-Slow: ") do |port|
      expect(code("http://images.test:#{port}/a.jpg")).to eq("image_unreachable")
    end
  end

  it "reports an error status as unreachable" do
    resolve("images.test" => "127.0.0.1")
    serve("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n") do |port|
      expect(code("http://images.test:#{port}/a.jpg")).to eq("image_unreachable")
    end
  end

  it "gives up on a host that never answers" do
    stub_const("#{described_class}::READ_TIMEOUT", 0.2)
    resolve("images.test" => "127.0.0.1")
    allow_loopback
    silent = TCPServer.new("127.0.0.1", 0)

    expect(code("http://images.test:#{silent.addr[1]}/a.jpg")).to eq("image_unreachable")
  ensure
    silent&.close
  end
end
