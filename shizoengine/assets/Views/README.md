# Views

The `Views/` directory contains UI view assets for the VJ application interface.

## Overview

Views define the layout and behavior of UI components in the application. They control how clips, patches, and other elements are displayed and interacted with.

## Components

| View | Description |
|------|-------------|
| **Clipview.asset** | Clip management and display view |
| **Patchview.asset** | Patch configuration and visualization view |

## Directory Structure

```
Views/
├── Clipview.asset    # Clip view configuration
└── Patchview.asset   # Patch view configuration
```

## Notes

- Views are loaded as `.asset` configuration files
- They define UI layout, controls, and interactions
- View configuration is processed by the engine at runtime
- Views can be customized per-project

## Navigation

- [Assets Overview](../README.md)
- [Generator Overview](../Generators/README.md)
