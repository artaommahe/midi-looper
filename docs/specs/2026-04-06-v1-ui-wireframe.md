# MIDI Looper iPhone App V1 UI Wireframe

Related document: `docs/specs/2026-04-04-v1-product-spec.md`

## Purpose

This document captures the agreed wireframe and UI behavior for the first usable version of the MIDI looper app.

The goal is a simple, performance-oriented single-screen layout that is easy to read and tap while playing.

This is intentionally a wireframe spec, not a visual design spec. It does not define theming, color, typography polish, or branding.

## Agreed V1 Main Screen

V1 uses a portrait-only single-screen pedalboard layout.

The screen has two main regions:
- a compact transport header at the top
- four equal-width track panels stacked vertically

Reference wireframe:

```text
=====================================================
 [ PLAY ]        MIDI OK        120 BPM      [● ○ ○ ○]
=====================================================

 TRK 1 | PLAYING                           [Q: MUTE]
+-------------------------+------+------+---+-------+
|                         |      |      |   |       |
|        REC / OD         | MUTE | SOLO |   | CLEAR |
|                         |      |      |   |       |
+-------------------------+------+------+---+-------+

 TRK 2 | EMPTY                             [Q: --]
+-------------------------+------+------+---+-------+
|                         |      |      |   |       |
|        REC / OD         | MUTE | SOLO |   | CLEAR |
|                         |      |      |   |       |
+-------------------------+------+------+---+-------+

 TRK 3 | RECORDING                         [Q: --]
+-------------------------+------+------+---+-------+
|                         |      |      |   |       |
|        REC / OD         | MUTE | SOLO |   | CLEAR |
|                         |      |      |   |       |
+-------------------------+------+------+---+-------+

 TRK 4 | PLAYING (SOLO)                    [Q: --]
+-------------------------+------+------+---+-------+
|                         |      |      |   |       |
|        REC / OD         | MUTE | SOLO |   | CLEAR |
|                         |      |      |   |       |
+-------------------------+------+------+---+-------+
```

## Header And Transport Area

The top header should stay compact and always visible.

It should contain:
- a single transport button
- compact MIDI connection status
- current tempo display
- a moving beat indicator

### Transport Button

V1 uses a single transport button.

Behavior:
- when transport is stopped, the button label is `PLAY`
- when transport is running, the button label is `STOP`
- pressing `STOP` returns transport to the loop start in v1

The control should use text, not icon-only labeling.

### MIDI Status

Use compact status text in the header:
- `MIDI OK`
- `MIDI OFF`

This can evolve later when connection handling becomes more detailed.

### Tempo Display

Tempo is shown in BPM.

Before the first loop is completed, the UI may show a placeholder such as `-- BPM`.

After the first completed loop, the displayed BPM reflects the tempo derived from that loop.

### Beat Indicator

V1 uses a four-cell moving beat indicator.

Example states:

```text
[● ○ ○ ○]
[○ ● ○ ○]
[○ ○ ● ○]
[○ ○ ○ ●]
```

The indicator should communicate current beat position clearly and should not depend on decorative animation.

## Track Panel Layout

The main area contains exactly four track panels, labeled:
- `TRK 1`
- `TRK 2`
- `TRK 3`
- `TRK 4`

All track panels should use the same structure and control positions so the user can build muscle memory.

Each track panel has two rows:
- a compact status row
- a large control row

### Status Row

The status row should contain:
- track label
- primary state text
- optional overlay text inline with the state
- a right-aligned queued-action badge

Examples:
- `TRK 1 | PLAYING`
- `TRK 2 | EMPTY`
- `TRK 3 | RECORDING`
- `TRK 4 | PLAYING (SOLO)`

Queued action examples:
- `[Q: MUTE]`
- `[Q: SOLO]`
- `[Q: CLEAR]`
- `[Q: REC]`
- `[Q: OD]`
- `[Q: --]`

### Control Row

Each track panel should contain four controls in a fixed arrangement:
- large `REC / OD`
- medium `MUTE`
- medium `SOLO`
- separated `CLEAR`

Layout intent:
- `REC / OD` is the dominant action and should be the largest button
- `MUTE` and `SOLO` are secondary controls
- `CLEAR` should be visually separated slightly from `MUTE` and `SOLO` because it is more destructive

## Track States And Labels

Visible primary state labels for v1:
- `EMPTY`
- `ARMED`
- `RECORDING`
- `PLAYING`
- `OVERDUB`

Visible overlays for v1:
- `(MUTED)`
- `(SOLO)`

Examples:
- `PLAYING (MUTED)`
- `PLAYING (SOLO)`
- `OVERDUB`

`OVERDUB` should be used when layering new events onto an existing loop, instead of reusing a more ambiguous `RECORDING` label.

## Interaction Rules Reflected In The UI

### Empty Track

Behavior:
- tapping `REC / OD` arms the track
- `MUTE` is disabled
- `SOLO` is disabled
- `CLEAR` has no practical effect in v1, but may remain visible for layout consistency

The state should read `ARMED` after the user taps `REC / OD` on an empty track.

### First Loop

Before a master loop exists:
- tapping `REC / OD` on an empty track arms recording
- the UI should show `ARMED`
- the first loop does not skip the armed state

### Queued Boundary Actions

Queued actions should be shown separately from the current state.

The current state should remain visible until the loop boundary is reached.

Example:
- current state: `PLAYING`
- queued badge: `[Q: MUTE]`

This avoids confusion between what is active now and what will happen on the next boundary.

## Disabled And Inactive Controls

When a track is `EMPTY`:
- `MUTE` is disabled
- `SOLO` is disabled

Disabled controls should remain in place and stay visually recognizable as unavailable, rather than disappearing or causing the layout to shift.

## Layout Priorities

The layout should optimize for:
1. fast state recognition
2. large tap targets
3. stable control positions
4. minimal visual clutter

Implementation should prefer keeping all four tracks visible on common iPhone sizes if that can be done without making controls too small.

## Out Of Scope For This Wireframe

This wireframe does not define:
- color system
- branding
- final typography choices
- animation polish beyond the functional beat indicator
- settings or secondary screens
- advanced connection management UI

## Notes For Implementation

When implemented in SwiftUI, the first pass should prioritize structural accuracy over appearance.

Useful implementation checkpoints:
- keep the screen on one main view
- keep all four track rows structurally identical
- drive the screen from simple preview or mock state first
- validate readability and tap size on a real iPhone-sized layout
