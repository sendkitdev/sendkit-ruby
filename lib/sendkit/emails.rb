# frozen_string_literal: true

module SendKit
  class Emails
    def initialize(client)
      @client = client
    end

    def send(from:, to:, subject:, html: nil, text: nil, cc: nil, bcc: nil,
             reply_to: nil, headers: nil, tags: nil, scheduled_at: nil, attachments: nil)
      payload = {from: from, to: to, subject: subject}
      payload[:html] = html if html
      payload[:text] = text if text
      payload[:cc] = cc if cc
      payload[:bcc] = bcc if bcc
      payload[:reply_to] = reply_to if reply_to
      payload[:headers] = headers if headers
      payload[:tags] = tags if tags
      payload[:scheduled_at] = scheduled_at if scheduled_at
      payload[:attachments] = attachments if attachments

      @client.post("/v1/emails", payload)
    end

    def send_mime(envelope_from:, envelope_to:, raw_message:)
      @client.post("/v1/emails/mime", {
        envelope_from: envelope_from,
        envelope_to: envelope_to,
        raw_message: raw_message
      })
    end
  end
end
