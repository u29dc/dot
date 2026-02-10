---
name: craft
description: Apply frontend and design engineering constraints for accessible, performant interfaces
argument-hint: [file or review]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Craft

Enforce UI engineering constraints that maximize clarity, accessibility, performance, and product character while eliminating generic AI-default design.

## How to Use

- `/craft` - apply this contract to current UI work
- `/craft <file>` - audit one file for violations and return exact fixes
- `/craft review` - run full pre-ship checklist and anti-pattern scan

## When to Apply

Use this skill for:

- New pages/components, redesigns, and interaction changes
- Form, modal, menu, tooltip, and navigation work
- Motion, theming, typography, spacing, and accessibility decisions
- UI performance tuning and mobile adaptation
- Final design/code review before shipping

## Delivery Contract

When invoked for reviews, return:

1. Violations by severity (`critical`, `high`, `medium`, `low`) with file references.
2. Why each issue harms usability, accessibility, or performance.
3. Minimal fix steps with concrete CSS/component changes.
4. Residual risk and verification checklist.

## Intent Protocol

Before implementation, define:

- User: exact person and context of use.
- Task: concrete verb/outcome, not feature label.
- Feel: explicit interaction character (for example precise, calm, editorial, dense).

If any are missing, ask before designing. Do not default.

Run these tests before shipping:

- Swap test: if common defaults can replace choices without impact, choices are weak.
- Squint test: hierarchy still visible when details blur.
- Signature test: at least five concrete elements reflect product character.
- Token test: token names reflect domain language, not generic placeholders.

## Stack and Component Rules

- MUST use project stack first; do not introduce parallel primitives without reason.
- MUST use accessible primitives (`Base UI`, `React Aria`, `Radix`) for keyboard/focus behavior.
- MUST use Tailwind constraints unless project standards differ.
- MUST use class composition utility (`cn` / `clsx` + `tailwind-merge`) for conditional classes.
- MUST use `motion/react` when JS animation is necessary.
- SHOULD use `tw-animate-css` for simple entrance/micro animations.
- SHOULD prefer open-code component patterns over opaque package wrappers.
- NEVER mix primitive systems on one interaction surface.
- NEVER rebuild keyboard/focus logic from scratch unless explicitly requested.

## Motion Rules

### Core constants

| Context                             | Duration  | Rule             |
| ----------------------------------- | --------- | ---------------- |
| Micro feedback (press/hover/toggle) | 100-150ms | keep under 200ms |
| Small surfaces (tooltip/dropdown)   | 150-200ms | fast settle      |
| Medium surfaces (modal/panel)       | 200-300ms | hard max 300ms   |
| Keyboard/high-frequency actions     | 0ms       | no animation     |

- MUST animate only `transform` and `opacity`.
- MUST keep button press tactile (`scale(0.97)`); entry scale >= `0.96`.
- MUST set correct `transform-origin` (for example popover from trigger).
- MUST support interruption; avoid keyframes for interactive state changes.
- MUST honor `prefers-reduced-motion` with reduced or disabled variants.
- SHOULD use custom easing:
    - `--ease-out: cubic-bezier(0.16, 1, 0.3, 1)`
    - `--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1)`
- SHOULD delay first tooltip; peer tooltips can appear instantly.
- SHOULD pause looping animation when off-screen.
- SHOULD use subtle blur bridging when state transitions visually snap.
- NEVER animate layout properties (`width/height/top/left/margin/padding`).
- NEVER use `transition: all`.
- NEVER animate from `scale(0)`.
- NEVER animate frequent keyboard-driven actions.

## Typography Rules

- MUST set `-webkit-font-smoothing: antialiased` and `text-rendering: optimizeLegibility`.
- MUST set mobile input size >= `16px` (prevents iOS zoom).
- MUST use `font-variant-numeric: tabular-nums` for numeric UI.
- MUST use balanced heading/body wraps (`text-balance`, `text-pretty`) when supported.
- SHOULD use fluid heading sizes with `clamp()`.
- SHOULD keep heading weight in readable ranges (typically 500-600 unless deliberate contrast).
- SHOULD use line truncation/clamp for dense UI with controlled overflow.
- NEVER change font-weight on hover/selection (layout shift risk).
- NEVER default to Inter/Roboto/Arial without explicit justification.
- NEVER use weak hierarchy deltas when stronger contrast is needed.

## Layout and Spacing Rules

- MUST align to deliberate grids, edges, and baseline rhythm.
- MUST validate at `375px`, `1024px`, and ultra-wide viewport.
- MUST account for safe areas (`env(safe-area-inset-*)`) on fixed UI.
- MUST prevent accidental overflow/horizontal scroll.
- MUST use a fixed spacing scale (4px/8px multiples).
- MUST keep padding symmetry unless asymmetry has purpose.
- MUST use fixed z-index ladder (for example `10/20/30/50`) instead of ad-hoc values.
- MUST use `h-dvh` over `h-screen` for mobile viewport correctness.
- SHOULD use optical alignment adjustments when geometry looks wrong.
- SHOULD prefer `size-*` for square dimensions.
- SHOULD prefer flex/grid over JS measurement hacks.

## Color and Theming Rules

- MUST use one intentional visual direction; avoid generic palette drift.
- MUST ensure contrast compliance (prefer APCA, meet WCAG minimums).
- MUST provide non-color status cues for critical states.
- MUST keep theme switch free of global transition flash.
- MUST set explicit control colors for problematic native controls (for example `<select>` on Windows).
- SHOULD set `color-scheme` appropriately and maintain matching browser theme color.
- SHOULD style `::selection` and verify readable selected text.
- SHOULD keep accent usage controlled (usually one dominant accent per view).
- SHOULD prefer layered shadows and tinted edges over heavy glow effects.
- SHOULD consider LCH for perceptual consistency in advanced systems.
- NEVER use "AI look" defaults (purple gradients, multicolor glow, random aesthetic noise).
- NEVER mix depth strategies within one surface set.

## Accessibility Rules (WCAG 2.2 + APG)

- MUST implement full keyboard navigation for all interactive flows.
- MUST show visible focus states with `:focus-visible`.
- MUST manage focus lifecycle in overlays (trap, move, return).
- MUST ensure icon-only controls have accessible names (`aria-label`).
- MUST ensure sequential heading hierarchy without skips.
- MUST ensure touch targets:
    - desktop minimum `24px`
    - mobile minimum `44px`
- MUST ensure labels activate form fields and interactive hit areas have no dead zones.
- MUST use `aria-live` appropriately for dynamic status messages.
- MUST avoid color-only semantics.
- MUST use native semantics before ARIA overrides.
- NEVER suppress outlines without visible replacement.
- NEVER use positive `tabIndex` ordering hacks.

## Forms and Input Rules

- MUST wrap submit flows in `<form>` for keyboard submission.
- MUST use semantic input types, `name`, and `autocomplete`.
- MUST surface inline validation near fields and focus first invalid field on submit.
- MUST set `aria-invalid` and `aria-describedby` correctly for errors.
- MUST keep submit enabled until request starts, then show loading/disabled feedback.
- MUST support paste in all text inputs and textareas.
- MUST preserve hydration/focus/value integrity.
- MUST warn on unsaved changes where loss risk exists.
- SHOULD prefer uncontrolled inputs unless controlled behavior is required.
- SHOULD disable spellcheck for emails, usernames, codes.
- SHOULD include idempotency protection for mutation requests.

## Interaction Rules

- MUST reflect shareable UI state in URL when state matters (tabs/filters/pagination).
- MUST preserve scroll restoration for back/forward navigation.
- MUST use anchors/links for navigation semantics.
- MUST use destructive confirmation patterns (`AlertDialog`) or Undo windows.
- MUST place feedback near triggering action when possible.
- MUST ensure toggles apply immediately unless explicit deferred mode exists.
- MUST ensure anything that appears clickable is clickable.
- SHOULD use optimistic updates with rollback.
- SHOULD use ellipsis for follow-up actions (`Rename...`) and loading text.
- SHOULD use mousedown-triggered menus where immediacy matters.
- SHOULD apply trajectory-friendly nested menu behavior to reduce accidental close.
- NEVER use `<div onClick>` for primary navigation controls.

## Touch and Mobile Rules

- MUST scope hover styles with `@media (hover: hover)`.
- MUST set `touch-action: manipulation` for standard touch UI.
- MUST contain overscroll in drawers/modals.
- MUST disable selection artifacts during drag interactions.
- MUST set `<video muted playsinline>` for iOS autoplay behavior.
- SHOULD avoid autofocus on mobile unless explicitly needed.
- SHOULD tune tap highlight color to design system.
- NEVER disable browser zoom (`user-scalable=no`, `maximum-scale=1`).

## Performance Rules

- MUST profile real bottlenecks (CPU/network throttling, render traces).
- MUST minimize re-renders and batch layout reads/writes.
- MUST keep mutation interactions fast (target <500ms perceived response).
- MUST virtualize large lists (>50 items).
- MUST prevent CLS with explicit media dimensions and skeleton parity.
- MUST pause/unmount off-screen heavy media.
- SHOULD preconnect critical origins and preload critical fonts.
- SHOULD adapt behavior to device/network capability.
- NEVER keep `will-change` active outside active animation windows.
- NEVER use effect hooks for logic that can be expressed declaratively.

## States and Content Rules

Every component/page MUST define:

- Default
- Loading
- Empty
- Error
- Disabled

Additional constraints:

- MUST give empty states one clear next action.
- MUST ensure disabled states are perceivable without color alone.
- MUST define hover/focus/pressed/disabled feedback for interactive elements.
- MUST handle sparse and dense data states without layout collapse.

## Design Token Rules

- MUST use domain-semantic naming where possible.
- MUST preserve consistent spacing/radius/typography scales.
- MUST prefer existing project token system before adding new tokens.
- SHOULD keep token surface minimal and composable.

## Modern CSS Guidance

Use when compatible with project/browser support:

- View Transitions API for route/surface transitions.
- Scroll-driven animations for narrative/progress patterns.
- Container queries and container units for component-responsive design.
- `interpolate-size: allow-keywords` for `height: auto` transitions.

Do not use these as visual gimmicks; use only when they improve comprehension or interaction quality.

## Review Workflow

1. Run checklist from `references/checklist.md`.
2. Scan anti-pattern matrix in `references/anti-patterns.md`.
3. Fix all critical/high issues.
4. Re-verify accessibility, motion, and performance constraints.
5. Summarize residual medium/low tradeoffs and rationale.

## Reference Index

- `references/index.md` - routing guide for craft references.
- `references/checklist.md` - pre-ship QA checklist.
- `references/anti-patterns.md` - bad vs good pattern matrix.
- `references/sources.md` - standards and practitioner references.
