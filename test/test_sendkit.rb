# frozen_string_literal: true

require "minitest/autorun"
require "socket"
require "json"
require_relative "../lib/sendkit"

# Simple mock HTTP server using TCPServer
def start_mock_server(&block)
  server = TCPServer.new("127.0.0.1", 0)
  port = server.addr[1]
  thread = Thread.new do
    loop do
      client = server.accept
      request_line = client.gets
      headers = {}
      while (line = client.gets) && line != "\r\n"
        key, value = line.split(": ", 2)
        headers[key] = value&.strip
      end
      body = client.read(headers["Content-Length"].to_i) if headers["Content-Length"]

      status, response_body = block.call(request_line, headers, body)
      status ||= 200
      response_body ||= "{}"

      client.print "HTTP/1.1 #{status} OK\r\n"
      client.print "Content-Type: application/json\r\n"
      client.print "Content-Length: #{response_body.bytesize}\r\n"
      client.print "\r\n"
      client.print response_body
      client.close
    rescue => e
      break
    end
  end
  [server, "http://127.0.0.1:#{port}", thread]
end

class TestClient < Minitest::Test
  def test_with_api_key
    client = SendKit::Client.new("sk_test_123")
    assert_instance_of SendKit::Client, client
  end

  def test_missing_api_key
    ENV.delete("SENDKIT_API_KEY")
    assert_raises(ArgumentError) { SendKit::Client.new }
  end

  def test_from_env_variable
    ENV["SENDKIT_API_KEY"] = "sk_from_env"
    client = SendKit::Client.new
    assert_instance_of SendKit::Client, client
  ensure
    ENV.delete("SENDKIT_API_KEY")
  end

  def test_custom_base_url
    client = SendKit::Client.new("sk_test_123", base_url: "https://custom.api.com")
    assert_instance_of SendKit::Client, client
  end
end

class TestEmailsSend < Minitest::Test
  def test_send_email
    captured = {}
    server, url, = start_mock_server do |request_line, headers, body|
      captured[:path] = request_line.split(" ")[1]
      captured[:method] = request_line.split(" ")[0]
      captured[:auth] = headers["Authorization"]
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-uuid-123"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    result = client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test Email",
      html: "<p>Hello</p>"
    )

    assert_equal "email-uuid-123", result["id"]
    assert_equal "/v1/emails", captured[:path]
    assert_equal "POST", captured[:method]
    assert_equal "Bearer sk_test_123", captured[:auth]
    assert_equal "sender@example.com", captured[:body]["from"]
    assert_equal "recipient@example.com", captured[:body]["to"]
    assert_equal "Test Email", captured[:body]["subject"]
  ensure
    server&.close
  end

  def test_send_with_optional_fields
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-uuid-456"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      reply_to: "reply@example.com",
      scheduled_at: "2026-03-01T10:00:00Z"
    )

    assert_equal "reply@example.com", captured[:body]["reply_to"]
    assert_equal "2026-03-01T10:00:00Z", captured[:body]["scheduled_at"]
  ensure
    server&.close
  end

  def test_send_mime_email
    captured = {}
    server, url, = start_mock_server do |request_line, _headers, body|
      captured[:path] = request_line.split(" ")[1]
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "mime-uuid-789"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    result = client.emails.send_mime(
      envelope_from: "sender@example.com",
      envelope_to: "recipient@example.com",
      raw_message: "From: sender@example.com\r\nTo: recipient@example.com\r\n\r\nHello"
    )

    assert_equal "mime-uuid-789", result["id"]
    assert_equal "/v1/emails/mime", captured[:path]
    assert_equal "sender@example.com", captured[:body]["envelope_from"]
    assert_equal "recipient@example.com", captured[:body]["envelope_to"]
  ensure
    server&.close
  end

  def test_api_error
    server, url, = start_mock_server do |_request_line, _headers, _body|
      [422, JSON.generate({
        "name" => "validation_error",
        "message" => "The to field is required.",
        "statusCode" => 422
      })]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    error = assert_raises(SendKit::Error) do
      client.emails.send(
        from: "sender@example.com",
        to: "",
        subject: "Test",
        html: "<p>Hi</p>"
      )
    end

    assert_equal "validation_error", error.name
    assert_equal 422, error.status_code
    assert_equal "The to field is required.", error.message
  ensure
    server&.close
  end
end
