# AGENTS.md

## Purpose

This repository contains an iPhone app project for live music performance use.

The app is being developed primarily through AI-assisted coding, with the user steering direction and validating behavior on real hardware. AI agents working in this repo should optimize for practical results, small changes, and easy validation.

## Source Of Truth

- Read the relevant product and technical docs under `docs/` before making substantial changes.
- Current and historical product specs live in `docs/specs/`.
- Prefer the latest dated spec file unless the user points to a different one.
- If code and spec disagree, do not guess. Check with the user or update the docs as part of the change.

## Development Priorities

Priority order:
1. correct behavior
2. stable real-device performance
3. simple and fast user interaction
4. implementation simplicity
5. visual polish

## General Coding Rules

- Keep the code minimal and direct.
- Prefer native platform frameworks unless a dependency is clearly justified.
- Avoid adding abstractions for hypothetical future needs.
- Avoid protocol-heavy or framework-heavy architecture without a concrete reason.
- Prefer modifying existing code over creating many new files.
- Keep comments sparse and only where behavior would otherwise be hard to follow.
- Make the smallest correct change first.

## Architecture Guidance

- Separate timing-critical or device-critical logic from UI state and rendering.
- Keep the architecture understandable by one person working with AI assistance.
- Do not over-split the codebase early.
- Favor simple module boundaries that match actual responsibilities in the app.

## AI Workflow Rules

- Make small, testable changes.
- Implement one milestone at a time.
- Do not combine major refactors with feature work unless explicitly requested.
- Explain non-trivial state-machine or behavior changes before implementing them.
- When introducing a new structure, justify why the simpler alternative is not enough.
- When a task depends on product behavior, refer back to the active spec.

## Validation Expectations

- Prefer real-device behavior over simulator behavior when the product interacts with hardware, timing, or performance-sensitive paths.
- After meaningful changes, provide a short manual validation checklist the user can run.
- Call out any behavior that could not be verified locally.

## Testing Guidance

- Prefer automated tests for deterministic logic such as state transitions, timing calculations, and event scheduling rules.
- Prefer manual real-device validation for hardware integration, latency, jitter, connection behavior, and other performance-sensitive paths.
- Do not add heavy test scaffolding or broad mocking layers unless they clearly improve confidence without distorting the design.
- Keep tests focused on behavior and correctness rather than implementation details.
- If a change is not covered by automated tests, state that clearly in the final handoff.

## Documentation Rules

- Put new product specs in `docs/specs/`.
- Use dated filenames in `YYYY-MM-DD-name.md` format for new spec-style docs.
- Update documentation when project rules or expected behavior materially change.
- Keep repo-level guidance in this file generic; put milestone- or version-specific requirements in spec documents.

## Change Management

- Keep commits small once development begins.
- Use Conventional Commits format for commit messages.
- Do not rewrite large areas without a concrete reason.
- If a simpler approach works, prefer it over a more general one.
- Do not silently change documented behavior.
