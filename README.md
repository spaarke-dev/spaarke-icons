# Spaarke Icons

Canonical icon library for all Spaarke applications. All icons are sourced from [Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons) and standardized to **20px Regular** style.

## Structure

```
icons/
  nav/        Navigation / sitemap icons (16 icons)
  entity/     Dataverse entity record type icons (27 icons)
  cmd/        Command bar, toolbar, and UI chrome icons (41 icons)
  status/     Status indicator icons (9 icons)
```

**93 total icons** across 4 categories.

## Usage

### Dataverse / Power Platform

Icons are deployed as **web resources** in the Spaarke Dataverse solution. The `icon-manifest.json` file maps each icon to its:

- **Entity logical name** (e.g., `sprk_matter`, `sprk_project`)
- **Web resource path** (e.g., `sprk_/icons/entity/matter.svg`)
- **Usage type** (entity, navigation, command, status)

Use the manifest to generate `customizations.xml` entries and sitemap icon references for PAC CLI packaging.

### React / Web Applications

Import icons directly from `@fluentui/react-icons` using the component name listed in the manifest's `fluentComponent` field:

```tsx
import { Briefcase20Regular } from '@fluentui/react-icons';
```

Or reference the SVG files directly from this repository for non-React applications.

### Prototype

The Spaarke UX prototype (`spaarke-prototype`) maintains a copy of these icons under `projects/spaarke-navigation-icons/src/assets/icons/` for visual testing and the Icon Manager tool.

## Icon Standard

| Property | Value |
|----------|-------|
| Size | 20px |
| Style | Regular |
| Format | SVG |
| Source | Fluent UI System Icons |
| Color | Inherits from context (currentColor) |

## Manifest

`icon-manifest.json` contains the complete machine-readable inventory with:
- Fluent UI component names (for React imports)
- Fluent UI SVG filenames (for MCP/CDN lookup)
- Dataverse web resource paths
- Entity logical names
- Usage type classification

## Updating Icons

1. Use the **Spaarke Icon Manager** experiment in the prototype to search, select, and approve icons
2. Export approved icons and copy SVGs to this repository
3. Update `icon-manifest.json` with new entries
4. Commit and push to make available across all applications
