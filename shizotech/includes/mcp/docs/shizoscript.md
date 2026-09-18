# ShizoScript

Skill instructions for working with ShizoScript.

## Key Rules
- No `while` loops, only `for`.
- No `{}` for data — use `[]` json notation.
- No `new`, no `null` (use `None`).
- Every statement ends with `;`.
- Lambdas require an explicit capture list.

## Verified API
- `std.print`, `std.string`, `std.json`, `std.sleep`
- `webserver.http_server` for HTTP endpoints
- `curl.curl` for outbound HTTP requests
