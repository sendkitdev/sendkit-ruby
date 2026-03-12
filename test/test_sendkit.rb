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
    assert_equal "/emails", captured[:path]
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

    assert_equal ["reply@example.com"], captured[:body]["reply_to"]
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
    assert_equal "/emails/mime", captured[:path]
    assert_equal "sender@example.com", captured[:body]["envelope_from"]
    assert_equal "recipient@example.com", captured[:body]["envelope_to"]
  ensure
    server&.close
  end

  def test_send_to_multiple_recipients
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-multi-to"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: ["alice@example.com", "bob@example.com"],
      subject: "Test",
      html: "<p>Hi</p>"
    )

    assert_equal ["alice@example.com", "bob@example.com"], captured[:body]["to"]
  ensure
    server&.close
  end

  def test_send_to_display_name_format
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-display-name"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "Sender Name <sender@example.com>",
      to: "Recipient Name <recipient@example.com>",
      subject: "Test",
      html: "<p>Hi</p>"
    )

    assert_equal "Sender Name <sender@example.com>", captured[:body]["from"]
    assert_equal "Recipient Name <recipient@example.com>", captured[:body]["to"]
  ensure
    server&.close
  end

  def test_send_with_text_body
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-text"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      text: "Hello plain text"
    )

    assert_equal "Hello plain text", captured[:body]["text"]
    assert_nil captured[:body]["html"]
  ensure
    server&.close
  end

  def test_send_with_cc
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-cc"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      cc: ["cc1@example.com", "cc2@example.com"]
    )

    assert_equal ["cc1@example.com", "cc2@example.com"], captured[:body]["cc"]
  ensure
    server&.close
  end

  def test_send_with_bcc
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-bcc"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      bcc: ["bcc1@example.com", "bcc2@example.com"]
    )

    assert_equal ["bcc1@example.com", "bcc2@example.com"], captured[:body]["bcc"]
  ensure
    server&.close
  end

  def test_send_with_cc_as_string
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-cc-string"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      cc: "cc@example.com"
    )

    assert_equal ["cc@example.com"], captured[:body]["cc"]
  ensure
    server&.close
  end

  def test_send_with_bcc_as_string
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-bcc-string"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      bcc: "bcc@example.com"
    )

    assert_equal ["bcc@example.com"], captured[:body]["bcc"]
  ensure
    server&.close
  end

  def test_send_with_reply_to_as_string
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-reply-to-string"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      reply_to: "reply@example.com"
    )

    assert_equal ["reply@example.com"], captured[:body]["reply_to"]
  ensure
    server&.close
  end

  def test_send_with_reply_to_as_array
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-reply-to-array"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      reply_to: ["reply1@example.com", "reply2@example.com"]
    )

    assert_equal ["reply1@example.com", "reply2@example.com"], captured[:body]["reply_to"]
  ensure
    server&.close
  end

  def test_send_with_headers
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-headers"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      headers: {"X-Custom-Header" => "custom-value", "X-Another" => "another-value"}
    )

    assert_equal "custom-value", captured[:body]["headers"]["X-Custom-Header"]
    assert_equal "another-value", captured[:body]["headers"]["X-Another"]
  ensure
    server&.close
  end

  def test_send_with_tags
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-tags"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    # Tags must be an array of hashes with "name" and "value" keys
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      tags: [{"name" => "category", "value" => "marketing"}, {"name" => "campaign_id", "value" => "abc123"}]
    )

    assert_equal 2, captured[:body]["tags"].length
    assert_equal({"name" => "category", "value" => "marketing"}, captured[:body]["tags"][0])
    assert_equal({"name" => "campaign_id", "value" => "abc123"}, captured[:body]["tags"][1])
  ensure
    server&.close
  end

  def test_send_with_attachments
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-attachments"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>",
      attachments: [
        {"filename" => "report.pdf", "content" => "base64encodedcontent", "content_type" => "application/pdf"},
        {"filename" => "image.png", "content" => "base64encodedimage", "content_type" => "image/png"}
      ]
    )

    assert_equal 2, captured[:body]["attachments"].length
    assert_equal "report.pdf", captured[:body]["attachments"][0]["filename"]
    assert_equal "image.png", captured[:body]["attachments"][1]["filename"]
  ensure
    server&.close
  end

  def test_nil_fields_omitted_from_payload
    captured = {}
    server, url, = start_mock_server do |_request_line, _headers, body|
      captured[:body] = JSON.parse(body)
      [200, JSON.generate({"id" => "email-nil-fields"})]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    client.emails.send(
      from: "sender@example.com",
      to: "recipient@example.com",
      subject: "Test",
      html: "<p>Hi</p>"
    )

    assert_equal %w[from to subject html], captured[:body].keys
    refute captured[:body].key?("text")
    refute captured[:body].key?("cc")
    refute captured[:body].key?("bcc")
    refute captured[:body].key?("reply_to")
    refute captured[:body].key?("headers")
    refute captured[:body].key?("tags")
    refute captured[:body].key?("scheduled_at")
    refute captured[:body].key?("attachments")
  ensure
    server&.close
  end

  def test_non_json_error_response
    server, url, = start_mock_server do |_request_line, _headers, _body|
      [502, "<html><body>Bad Gateway</body></html>"]
    end

    client = SendKit::Client.new("sk_test_123", base_url: url)
    error = assert_raises(SendKit::Error) do
      client.emails.send(
        from: "sender@example.com",
        to: "recipient@example.com",
        subject: "Test",
        html: "<p>Hi</p>"
      )
    end

    assert_equal 502, error.status_code
    assert_equal "unknown_error", error.name
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
