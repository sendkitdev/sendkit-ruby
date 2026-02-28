# SendKit Ruby SDK

## Project Overview

Ruby SDK for the SendKit email API. Uses `net/http` (stdlib), zero external dependencies.

## Architecture

```
lib/sendkit/
├── version.rb   # VERSION constant
├── error.rb     # SendKit::Error exception class
├── client.rb    # SendKit::Client: holds API key, post() method
└── emails.rb    # SendKit::Emails (send, send_mime)
```

- `SendKit::Client` is the entry point, accepts api_key + optional base_url
- `client.emails` exposes email operations
- Uses keyword arguments for all params
- API errors raise `SendKit::Error` with name, message, status_code
- `POST /v1/emails` for structured emails, `POST /v1/emails/mime` for raw MIME

## Testing

- Tests use Minitest + WEBrick for mock HTTP servers
- Run tests: `bundle exec rake test`
- No external test dependencies beyond minitest

## Releasing

- Tags use numeric format: `1.0.0` (no `v` prefix)
- CI runs tests on Ruby 3.1, 3.2, 3.3
- Pushing a tag creates GitHub Release + publishes to RubyGems via trusted publishing

## Git

- NEVER add `Co-Authored-By` lines to commit messages
