# WireMock Documentation

This directory contains configuration for the WireMock server used to mock API responses in your Maestro tests.

## How to add a new mock

1.  Create a new JSON file in the `mappings/` directory.
2.  Define the `request` (method, URL, headers, etc.) and the `response` (status, body, headers).
3.  Restart the wiremock service or use the Admin API to reload mappings.

### Example mapping

```json
{
  "request": {
    "method": "POST",
    "url": "/api/v1/login"
  },
  "response": {
    "status": 200,
    "body": "{\"token\": \"fake-jwt-token\"}",
    "headers": {
      "Content-Type": "application/json"
    }
  }
}
```

## Admin API

You can view active mappings and recorded requests by visiting:
`http://localhost:8080/__admin` (from your host machine)

## Using in App

Ensure your application points to `http://10.0.2.2:8080` (Standard Android Emulator redirect to host) or the designated mock server URL.
