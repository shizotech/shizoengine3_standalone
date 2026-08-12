# Dashboard Backend Implementation Guide

## Overview

This document describes the backend implementation for the dashboard API endpoints in the ShizoScript webserver.

## Files

### Core Implementation

- `__init__.shio` - Main entry point (includes dashboard_api.shio)
- `dashboard_api.shio` - Dashboard API endpoint implementations

### Documentation

- `dashboard_backend_docs/API_DESIGN.md` - Complete API specification
- `dashboard_backend_docs/IMPLEMENTATION.md` - This file

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Web Server (port 13337)                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Endpoints                            │  │
│  │ ┌────────────────────────────────────────────────────┐ │  │
│  │ │ /api/features/  - Feature CRUD operations         │ │  │
│  │ └────────────────────────────────────────────────────┘ │  │
│  │ ┌────────────────────────────────────────────────────┐ │  │
│  │ │ /api/bugs/      - Bug CRUD operations             │ │  │
│  │ └────────────────────────────────────────────────────┘ │  │
│  │ ┌────────────────────────────────────────────────────┐ │  │
│  │ │ /api/history/   - History CRUD operations         │ │  │
│  │ └────────────────────────────────────────────────────┘ │  │
│  │ ┌────────────────────────────────────────────────────┐ │  │
│  │ │ /api/workmode/  - Work Mode control               │ │  │
│  │ └────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                   LevelDB Databases                          │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  features.db     │  │   bugs.db        │                │
│  └──────────────────┘  └──────────────────┘                │
│  ┌──────────────────┐                                       │
│  │  history.db      │                                       │
│  └──────────────────┘                                       │
└──────────────────────────────────────────────────────────────┘
```

## Database Layout

```
agent_space/
├── dashboard/
│   ├── features.db    # Features storage
│   ├── bugs.db        # Bugs storage
│   └── history.db     # History storage
```

## API Implementation

### Features Endpoints

All features endpoints use regex pattern `^/api/features/([a-zA-Z0-9_]+)$` for ID matching.

#### GET /api/features/list

```shizoscript
// Returns all features from database
// Response: { ok: true, data: [features] }
```

#### GET /api/features/:id

```shizoscript
// Returns specific feature by ID
// Response: { ok: true, data: feature } or { ok: false, error: "Feature not found" }
```

#### POST /api/features

```shizoscript
// Creates new feature with auto-generated ID
// Request Body: Feature object (partial)
// Response: { ok: true, data: created_feature }
```

**Required Fields:** None (all fields optional, defaults applied)

**Auto-generated Fields:**
- `id` - Feature ID
- `createdAt` - Timestamp
- `updatedAt` - Timestamp
- `progress` - 0
- `status` - "planned"

#### PUT /api/features/:id

```shizoscript
// Updates existing feature
// Request Body: Feature updates (partial)
// Response: { ok: true, data: updated_feature } or { ok: false, error: "Feature not found" }
```

#### DELETE /api/features/:id

```shizoscript
// Deletes feature by ID
// Response: { ok: true } or { ok: false, error: "Feature not found" }
```

### Bugs Endpoints

All bugs endpoints use regex pattern `^/api/bugs/([a-zA-Z0-9_]+)$` for ID matching.

#### GET /api/bugs/list

```shizoscript
// Returns all bugs from database
// Response: { ok: true, data: [bugs] }
```

#### GET /api/bugs/:id

```shizoscript
// Returns specific bug by ID
// Response: { ok: true, data: bug } or { ok: false, error: "Bug not found" }
```

#### POST /api/bugs

```shizoscript
// Creates new bug with auto-generated ID
// Request Body: Bug object (partial)
// Response: { ok: true, data: created_bug }
```

**Auto-generated Fields:**
- `id` - Bug ID
- `createdAt` - Timestamp
- `updatedAt` - Timestamp
- `status` - "new"

#### PUT /api/bugs/:id

```shizoscript
// Updates existing bug
// Request Body: Bug updates (partial)
// Response: { ok: true, data: updated_bug } or { ok: false, error: "Bug not found" }
```

#### DELETE /api/bugs/:id

```shizoscript
// Deletes bug by ID
// Response: { ok: true } or { ok: false, error: "Bug not found" }
```

### History Endpoints

All history endpoints use regex pattern `^/api/history/([a-zA-Z0-9_]+)$` for ID matching.

#### GET /api/history/list

```shizoscript
// Returns all history entries from database
// Response: { ok: true, data: [entries] }
```

#### GET /api/history/:id

```shizoscript
// Returns specific history entry by ID
// Response: { ok: true, data: entry } or { ok: false, error: "History entry not found" }
```

#### POST /api/history

```shizoscript
// Creates new history entry
// Request Body: Entry object (partial)
// Response: { ok: true, data: created_entry }
```

**Auto-generated Fields:**
- `id` - History ID
- `timestamp` - Current timestamp

#### PUT /api/history/:id

```shizoscript
// Updates existing history entry
// Request Body: Entry updates (partial)
// Response: { ok: true, data: updated_entry } or { ok: false, error: "History entry not found" }
```

#### DELETE /api/history/:id

```shizoscript
// Deletes history entry by ID
// Response: { ok: true } or { ok: false, error: "History entry not found" }
```

## Error Handling

All endpoints include try-catch blocks for robust error handling:

```shizoscript
try {
    // Database operations
    return [body = format_api_response(true, data)];
}
catch(e) {
    return [body = format_api_response(false, None, std.string(e))];
}
```

## Integration with Main Application

The dashboard API is included in `__init__.shio`:

```shizoscript
//Start webserver
server = webserver.http_server(13337);
server.static("", "web"); //TODO: add functions to only serve certain routes when AUTHED\t

#include "dashboard_api"

server.start();
```

## Frontend Polling Strategy

### Initial Load

```javascript
// When module loads
fetch('/api/features/list')
  .then(r => r.json())
  .then(data => {
    if(data.ok) {
      store.load(data.data);
      render();
    }
  });
```

### Regular Polling

```javascript
// Poll every 2 seconds
setInterval(() => {
  fetch('/api/features/list')
    .then(r => r.json())
    .then(data => {
      if(data.ok) {
        store.sync(data.data);
      }
    });
}, 2000);
```

## Testing

### Manual Testing with curl

```bash
# Test features list
curl http://localhost:13337/api/features/list

# Create a feature
curl -X POST http://localhost:13337/api/features \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Feature","description":"Test description"}'

# Get specific feature
curl http://localhost:13337/api/features/feature_...

# Update feature
curl -X PUT http://localhost:13337/api/features/feature_... \
  -H "Content-Type: application/json" \
  -d '{"status":"in-progress"}'

# Delete feature
curl -X DELETE http://localhost:13337/api/features/feature_...
```

### Expected Response Format

```json
{
  "ok": true,
  "data": {
    "id": "feature_...",
    "title": "Test Feature",
    "description": "Test description",
    "priority": "medium",
    "category": "feature",
    "status": "planned",
    "progress": 0,
    "createdAt": 1715000000000,
    "updatedAt": 1715000000000
  }
}
```

## Performance Considerations

1. **Database Connection:** LevelDB handles caching internally
2. **Concurrent Requests:** Webserver handles concurrent connections
3. **Data Size:** Full list responses on every poll (acceptable for <1000 entries)
4. **Memory:** JSON serialization handled by ShizoScript runtime

## Security Notes

1. **No Authentication:** Current implementation has no auth (development mode)
2. **Input Validation:** Basic JSON parsing validation
3. **SQL Injection:** LevelDB is key-value store, not SQL, so SQL injection not applicable
4. **XSS:** Frontend should sanitize output

## Future Enhancements

1. **Authentication:** Add JWT or session-based auth
2. **Rate Limiting:** Implement request throttling
3. **Input Validation:** Add schema validation
4. **CORS Headers:** Add proper CORS configuration
5. **HTTPS:** Add SSL certificate support

## Troubleshooting

### Database Not Found

```bash
# Check if agent space exists
ls -la .agent/dashboard/

# Create if missing
mkdir -p .agent/dashboard/
```

### Port Already in Use

```bash
# Change port in __init__.shio
server = webserver.http_server(NEW_PORT);
```

### JSON Parse Errors

```shizoscript
// Use parse_request_body helper
body = parse_request_body(req.body);
if(!body) {
    return [body = format_api_response(false, None, "Invalid JSON")];
}
```
