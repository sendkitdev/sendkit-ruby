# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module SendKit
  class Client
    DEFAULT_BASE_URL = "https://api.sendkit.com"

    attr_reader :emails

    def initialize(api_key = nil, base_url: DEFAULT_BASE_URL)
      @api_key = api_key || ENV["SENDKIT_API_KEY"]

      raise ArgumentError, 'Missing API key. Pass it to the constructor `SendKit::Client.new("sk_...")` or set the SENDKIT_API_KEY environment variable.' if @api_key.nil? || @api_key.empty?

      @base_url = base_url
      @emails = Emails.new(self)
    end

    def post(path, body)
      uri = URI("#{@base_url}#{path}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      parsed = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error.new(
          parsed["message"] || response.message,
          name: parsed["name"] || "application_error",
          status_code: response.code.to_i
        )
      end

      parsed
    end
  end
end
