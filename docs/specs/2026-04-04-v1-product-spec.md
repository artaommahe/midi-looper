# MIDI Looper iPhone App V1 Product Spec

Related document: `docs/architecture/2026-04-04-v1-architecture.md`

## Context

This project is a personal-use iPhone app for live MIDI looping with a Roland FP-10 piano.

Primary usage:
- connect the FP-10 to an iPhone over USB MIDI
- play the piano normally
- have the app pass MIDI through back to the FP-10 with minimal added latency
- record several MIDI loops
- play those loops back to the FP-10 at the same time
- control loops quickly during live playing

The app should feel closer to a simple live looper pedalboard than a DAW.

This project is not currently intended for App Store release. The immediate goal is a stable, practical personal tool with a minimal UI and strong timing behavior.

## Product Goal

Build a standalone native iPhone app that acts as a low-friction MIDI looper for a Roland FP-10.

The app should:
- receive MIDI from the FP-10
- immediately send live MIDI back to the FP-10
- record MIDI loop events per track
- replay those loop events back to the FP-10 in sync
- allow fast live control of 4 loop tracks

All sound should come from the FP-10, not from the iPhone.

## Core Design Principles

- low latency and low jitter are the top priority
- the app should be fast to use during live playing
- UI should be simple, direct, and performance-oriented
- timing-critical logic must be independent from the UI thread
- v1 should stay intentionally small and avoid overengineering

## Platform And Technical Direction

- platform: iPhone
- app type: standalone native iOS app
- language: Swift
- UI: SwiftUI
- MIDI I/O: CoreMIDI
- audio generation: none in v1
- third-party audio frameworks: none required in v1

## V1 Requirements

### Functional Requirements

- connect to Roland FP-10 over USB MIDI
- support MIDI input from the FP-10
- support MIDI output back to the FP-10
- provide immediate MIDI thru from input to output
- support 4 loop tracks
- record MIDI note and pedal events into loops
- first recorded loop defines the master loop length
- tempo is derived from the first completed loop in v1
- later tracks follow the same master loop length
- quantize record start and record end to loop boundaries
- support overdub by layering new MIDI events onto an existing track
- allow per-track mute
- allow per-track solo
- allow per-track clear
- allow global play/stop
- show a visual metronome or beat indicator
- show clear track state feedback

### Performance Requirements

- live MIDI thru must feel immediate in normal use
- loop playback timing must remain stable over time
- UI updates must not interfere with timing
- stopping, muting, and soloing must avoid stuck notes

### UX Requirements

- usable from a single main screen
- large, obvious controls suitable for live use
- state changes should be easy to understand at a glance
- mute, solo, and clear changes apply at loop boundaries in v1

## Out Of Scope For V1

- audio looping
- internal piano or synth playback
- session save and load
- export and import
- cloud sync
- advanced MIDI editing
- piano roll editor
- per-track instruments
- Bluetooth MIDI as a primary target
- AUv3 or plugin support
- App Store release preparation

## Main Behavioral Rules

- the first completed loop sets the session's master loop length
- the first completed loop also defines the session tempo
- all other tracks loop against that same length
- record start is quantized
- record stop is quantized
- overdub layers additional MIDI events rather than replacing existing ones
- mute changes apply on the next loop boundary
- solo changes apply on the next loop boundary
- clear changes apply on the next loop boundary
- live MIDI thru should continue while looping is active
- note-off safety must be enforced when muting, soloing, or stopping playback
- sustain pedal events must be handled correctly

## UI Concept

The app should resemble a live looper pedalboard.

### Main Screen

Top section:
- global play and stop control
- global record status or clock status
- tempo display derived from the first completed loop
- visual beat or bar indicator

Main section:
- 4 large track panels

Each track panel should show:
- track number or name
- current state
- Rec/OD control
- Mute control
- Solo control
- Clear control
- visual indication of whether a boundary action is queued

### Track States

Primary visible states:
- empty
- armed
- recording
- playing

Track state should be modeled as a primary playback state plus optional control overlays.

In v1:
- `muted` is an overlay on top of a primary state such as `playing`
- `soloed` is an overlay on top of a primary state such as `playing`
- muted and soloed are not standalone primary states

Exact internal implementation can evolve, but the visible behavior should stay simple.

## Non-Functional Priorities

Priority order:
1. timing correctness
2. low-friction live UX
3. implementation simplicity
4. visual polish

## Final V1 Outcome

A successful v1 is an iPhone app that lets the user:
- connect an FP-10 over USB MIDI
- play normally through the app with acceptable feel
- record a first loop that sets the master length
- derive tempo from that first completed loop
- overdub up to 4 synchronized MIDI tracks
- mute, solo, clear, and stop tracks predictably at loop boundaries
- use the app comfortably from one screen during live playing

If those behaviors are stable on a real device with the FP-10, v1 is successful.
