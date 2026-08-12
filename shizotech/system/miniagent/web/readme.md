# Web Dashboard Ecosystem

A modern dashboard ecosystem that integrates with the existing chat interface while maintaining its perfect UI.

## Architecture Overview

The dashboard ecosystem follows a modular architecture where:

- **Main Dashboard**: `dashboard.html` serves as the central hub
- **Chat Module**: `chat/` - Original chat interface as one module among others
- **Feature Tracker**: `features/` - Track feature requests and progress
- **Bug Tracker**: `bugs/` - Manage bugs with status workflow
- **History**: `history/` - Track all dashboard actions
- **Shared Components**: `components/` - Common CSS and JS utilities

## Files and Directories

```
web/
├── dashboard.html          # Main dashboard container
├── dashboard.css           # Dashboard-specific styles
├── dashboard.js            # Dashboard orchestration logic
├── components/
│   ├── ui.css             # Shared UI components
│   └── utils.js           # Shared utility functions
├── chat/                  # Chat module
│   ├── index.html         # Chat container
│   ├── style.css          # Chat styling
│   └── script.js          # Chat integration logic
├── features/              # Feature tracker
│   ├── index.html         # Feature view
│   ├── style.css          # Feature styles
│   └── script.js          # Feature management
├── bugs/                  # Bug tracker
│   ├── index.html         # Bug view
│   ├── style.css          # Bug styles
│   └── script.js          # Bug management
└── history/               # Action history
    ├── index.html         # History view
    ├── style.css          # History styles
    └── script.js          # History management
```

## Theme Palette

All components use the green/black theme:

- **--accent**: `linear-gradient(135deg, #005c4b 0%, #00a884 100%)`
- **--success**: `#00a884`
- **--danger**: `#8b6c6c`

## Navigation

Use the sidebar to navigate between modules:

- **Chat** - Original chat interface
- **Features** - Feature tracker
- **Bug Tracker** - Bug management
- **History** - Action history

## Features

### Work Mode
- **Toggle agent activity**: Enable/disable automated agent processing
- **Backend persistence**: State synchronized with LevelDB via `/api/workmode` endpoints
- **localStorage backup**: Offline support with fallback synchronization
- **Real-time sync**: API calls on toggle with error handling and UI rollback

### Feature Tracker
- Add, update, delete features
- Priority levels (low, medium, high, critical)
- Status workflow (planned, in-progress, completed)
- Progress tracking with visual progress bars
- Category tags
- Target dates

### Bug Tracker
- Report and track bugs
- Priority levels
- Status workflow (new, investigating, fixing, verified, closed)
- Human verification interface
- Environment tracking
- Source tracking

### History
- Timeline view of all actions
- Filter by type and time range
- Revert functionality for supported actions
- Detailed action history

### Shared Components

#### UI Components (`components/ui.css`)
- Cards, badges, buttons
- Responsive grid system
- Modal and dialog styles
- Status badge styles
- Progress indicators
- Timeline visualization

#### Utilities (`components/utils.js`)
- Date formatters
- Status badge generator
- Modal manager
- Storage utilities
- DOM utilities
- Feature/Bug/History managers

## Usage

1. Open `dashboard.html` in your browser
2. Navigate between modules using the sidebar
3. Each module operates independently but shares the dashboard theme
4. Data is persisted using localStorage with optional backend sync
5. **Work Mode**: Toggle agent activity via the Work Mode button in the sidebar (syncs with backend `/api/workmode` endpoints)

## Constraints

- The original `index.html`, `style.css`, and `script.js` files are NOT modified
- Each dashboard module is self-contained with its own HTML/CSS/JS
- All modules share the green/black theme
- Mobile-responsive design throughout
