# SendKit Ruby SDK

Official Ruby SDK for the [SendKit](https://sendkit.com) email API.

## Installation

```bash
gem install sendkit
```

Or add to your Gemfile:

```ruby
gem "sendkit"
```

## Usage

### Create a Client

```ruby
require "sendkit"

client = SendKit::Client.new("sk_your_api_key")
```

### Send an Email

```ruby
result = client.emails.send(
  from: "you@example.com",
  to: "recipient@example.com",
  subject: "Hello from SendKit",
  html: "<h1>Welcome!</h1>"
)

puts result["id"]
```

### Send a MIME Email

```ruby
result = client.emails.send_mime(
  envelope_from: "you@example.com",
  envelope_to: "recipient@example.com",
  raw_message: mime_string
)
```

### Error Handling

API errors raise `SendKit::Error`:

```ruby
begin
  client.emails.send(...)
rescue SendKit::Error => e
  puts e.name        # e.g. "validation_error"
  puts e.message     # e.g. "The to field is required."
  puts e.status_code # e.g. 422
end
```

### Configuration

```ruby
# Read API key from SENDKIT_API_KEY environment variable
client = SendKit::Client.new

# Custom base URL
client = SendKit::Client.new("sk_...", base_url: "https://custom.api.com")
```
