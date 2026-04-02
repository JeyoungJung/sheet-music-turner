# SheetMusicTurner

A sheet music reader for iPad with instant page turns, fullscreen display, and Apple Pencil annotation.

Built for iPad Pro. Designed for live performance.

---

## Features

**Reader**
- Instant page turns — zero render delay, pre-rendered page cache
- Fullscreen height-fit display (fills entire iPad screen, no gaps)
- Tap zones: left (previous), right (next), center (toggle UI)
- Keyboard & foot pedal support (← → arrows, spacebar)
- Pinch-to-zoom in annotation mode

**Annotations**
- Pen — Apple Pencil only drawing with PencilKit
- Eraser — bitmap eraser
- Instant Eraser — one-touch stroke deletion
- Lasso — select and move strokes
- Persistent across page turns and app relaunch

**Library**
- Import PDFs and images (JPEG, PNG, HEIC)
- Single-level folder organization
- Images auto-converted to PDF at import

**Setlists**
- Named, persistent setlists
- Drag-to-reorder pieces
- Playback mode with continuous page advancement across pieces
- Tap-to-advance through setlist items

---

## Requirements

- iPadOS 17.0+
- iPad only (not available on iPhone or Mac)
- Xcode 15+

---

## Build

```bash
xcodebuild -scheme SheetMusicTurner \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build
```

---

## Architecture

```
SheetMusicTurner/
├── App/                  # App entry point, root navigation
├── Assets.xcassets/      # Colors, app icon
├── Data/                 # SwiftData models, annotation persistence
├── Design/               # Design tokens (typography, spacing, colors)
├── Library/              # File import, folder management, library UI
├── Reader/               # PDF rendering, page viewer, annotation tools
└── Setlist/              # Setlist creation, ordering, playback
```

### Rendering Pipeline

PDFKit's `PDFView` is not used. Pages are rendered via a custom pipeline for zero-delay page turns:

```
CGPDFDocument
  → PageImageRenderer (background queue, Retina scale)
    → PageImageCache (NSCache, 16-page LRU, async prerender ±3 pages)
      → ImagePageView (UIImageView + PKCanvasView overlay)
        → PagedImageViewer (tap zones, zoom, keyboard input)
```

### Annotation Coordinate System

Annotations use a fixed canonical coordinate space based on screen bounds. When fullscreen toggles, only the canvas transform changes — stroke positions stay stable.

---

## Design

Editorial design system (adapted from CreditTrackerV3):
- **Typography**: Inter, flush-left
- **Colors**: Adaptive light/dark, gold accent (#C8A55A / #D4B56A)
- **Cards**: 22pt corner radius, surface background, subtle separator border
- **Motion**: Smooth spring animations, staggered entrances
- **Spacing**: Generous whitespace, 20pt screen padding
