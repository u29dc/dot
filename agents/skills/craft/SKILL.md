---
name: craft
description: Apply frontend and design engineering constraints for accessible, performant interfaces
argument-hint: [file or review]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Craft

Opinionated constraints for building accessible, fast, delightful interfaces where every rule prevents measurable user harm or perceivable quality degradation.

## How to Use

- `/craft` - apply these constraints to any UI work in this conversation
- `/craft <file>` - review file against all constraints, output violations, impact, and fixes
- `/craft review` - run full review checklist (swap test, squint test, signature test, token test, technical checklist)

## When to Apply

Reference these guidelines when:

- Building or modifying UI components, pages, layouts
- Implementing forms, inputs, buttons, modals, menus
- Adding animations, transitions, interactions
- Reviewing code for accessibility, performance, UX
- Designing color palettes, typography, spacing systems
- Creating empty states, loading states, error states

## Philosophy

### Intent-First Design

Before touching code, answer these explicitly:

**Who is this human?** Not "users." The actual person. Where are they when they open this? What did they do 5 minutes ago, what will they do 5 minutes after?

**What must they accomplish?** Not "use the dashboard." The verb. Grade these submissions. Find the broken deployment. Approve the payment.

**What should this feel like?** "Clean and modern" means nothing. Warm like a notebook? Cold like a terminal? Dense like a trading floor? Calm like a reading app?

If you cannot answer these with specifics, stop. Ask. Do not guess. Do not default.

### Every Choice Must Be Justified

For every decision, explain WHY:

- Why this layout and not another?
- Why this color temperature?
- Why this typeface?
- Why this spacing scale?
- Why this information hierarchy?

If your answer is "it's common" or "it's clean" or "it works"--you haven't chosen. You've defaulted. Defaults are invisible. Invisible choices compound into generic output.

**The swap test:** If you swapped your choices for the most common alternatives and the design didn't feel meaningfully different, you never made real choices.

### Sameness Is Failure

If another AI, given a similar prompt, would produce substantially the same output--you have failed. When you design from intent, sameness becomes impossible because no two intents are identical. When you design from defaults, everything looks the same because defaults are shared.

### Craft Is Compound Interest

A single 200ms animation matters little. But consistent animation timing, proper transform-origin, interruptible transitions, no animation on frequent actions, accessible focus states, and optical alignment--together they create interfaces that feel "right" in ways users can sense but not articulate. Dozens of invisible details executed consistently is what separates good from great.

Build with these rules as defaults. Break them deliberately, not accidentally. The goal isn't to follow a checklist--it's to internalize the principles until craft becomes instinct.

## Stack

### Required

- MUST use Tailwind CSS defaults unless custom values exist or are explicitly requested
- MUST use `cn` utility (`clsx` + `tailwind-merge`) for class logic
- MUST use `motion/react` when JavaScript animation is required
- SHOULD use `tw-animate-css` for entrance and micro-animations
- SHOULD prefer Biome over ESLint/Prettier

### Components

- MUST use accessible primitives for keyboard/focus behavior (`Base UI`, `React Aria`, `Radix`)
- MUST use the project's existing component primitives first
- SHOULD prefer `Base UI` for new primitives if stack-compatible
- SHOULD prefer open-code component patterns (components copied into project, not installed as packages) for maximum control
- SHOULD use two-layer architecture: structure/behavior primitives (Radix, React Aria) + style layer (Tailwind)
- SHOULD prefer composition over configuration--shared composable interfaces with predictable APIs
- NEVER mix primitive systems within the same interaction surface
- NEVER rebuild keyboard or focus behavior by hand unless explicitly requested

### Constraint-Based Design in Code

- MUST use predefined spacing scales and color palettes--never arbitrary values
- MUST extract React/Vue components, not CSS class abstractions (`@apply btn btn-primary` is an anti-pattern)
- SHOULD use Tailwind's core utility classes to enforce design constraints automatically

## Animation & Motion

### Core Principle

The difference between good and great interaction comes down to timing, easing, and knowing when NOT to animate. UI animations should rarely exceed 200ms. Buttons should scale to 0.97 on press (never to 0). High-frequency actions should have zero animation.

### Timing

| Duration  | Use Case                                       |
| --------- | ---------------------------------------------- |
| 100-150ms | Micro-feedback (hovers, button press, toggles) |
| 150-200ms | Small transitions (dropdowns, tooltips)        |
| 200-300ms | Medium transitions (modals, panels)            |
| <300ms    | Maximum for any UI animation                   |

- MUST keep interaction feedback under 200ms
- MUST keep all UI animations under 300ms
- SHOULD add 150-300ms show-delay for loading spinners to avoid flicker on fast responses
- SHOULD ensure minimum visible time of 300-500ms for loading states (users need confirmation it worked)

### Easing

```css
--ease-out: cubic-bezier(0.16, 1, 0.3, 1); /* Entrances - decelerate */
--ease-in: cubic-bezier(0.55, 0, 1, 0.45); /* Exits - accelerate */
--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1); /* Playful overshoot */
```

- MUST use `ease-out` for entrances (arrives fast, settles gently--feels responsive because acceleration happens at the beginning)
- SHOULD use `ease-in` for exits (builds momentum before departure)
- SHOULD use custom easing curves--built-in CSS easings are too weak
- NEVER introduce random easing curves unless explicitly requested

### What to Animate

- MUST animate only compositor-friendly props (`transform`, `opacity`)
- MUST ensure animations are interruptible and input-driven (CSS transitions can be interrupted mid-animation; CSS keyframes cannot--avoid keyframes for interactive elements)
- MUST set correct `transform-origin` (motion starts where it physically should--popovers scale from their trigger, not center)
- MUST pause looping animations when off-screen
- MUST use SVG transforms on `<g>` wrapper with `transform-box: fill-box`
- SHOULD apply `filter: blur(2px)` to bridge visual gaps between states (tricks the eye into seeing smooth transition when nothing else works)
- SHOULD animate only to clarify cause/effect or add deliberate delight

### What NOT to Animate

- NEVER animate layout properties (`width`, `height`, `top`, `left`, `margin`, `padding`)
- NEVER animate paint properties on large surfaces (`background`, `color`)
- NEVER animate large `blur()` or `backdrop-filter` surfaces
- NEVER use `transition: all`--list properties explicitly
- NEVER animate from `scale(0)`--start at 0.93 or higher (zero scale feels wrong because it looks like the element comes out of nowhere--a higher initial value resembles the real world, like a balloon that even when deflated has a visible shape)
- NEVER add animation unless explicitly requested

### The Frequency x Novelty Rule

Before animating, evaluate how often the element is used and how novel the animation is. This is the most important animation decision framework:

**High frequency + low novelty = NO animation.** Elements used tens or hundreds of times daily should have zero animation. Context menus, command palettes, keyboard-triggered actions.

**Keyboard-initiated actions: NEVER animate.** These repeated actions feel slow, delayed, and disconnected when animated.

**Clear user intent = animation is friction.** When users have a goal, animation adds friction. "I just want to do my work with no unnecessary friction."

**The Daily Annoyance Test:** A morphing feedback component is a pleasant surprise if rarely seen. Used multiple times daily, it quickly becomes irritating. Initial delight fades into irritation.

**Concrete examples of NO animation:**

- Command menus open instantly (no fade)
- Right-click menus appear instantly (only fade OUT)
- App Switcher never animates
- Fast keyboard shortcut sequences skip animation entirely
- Removing motion from core interactions makes everything feel faster

Sometimes the best animation is no animation.

### Implementation

- MUST honor `prefers-reduced-motion` (provide reduced variant or disable)
- SHOULD prefer CSS > Web Animations API > JS libraries
- SHOULD use `scroll-behavior: smooth` for in-page anchors with offset

### Tooltip Timing Pattern

```css
[data-state="instant"] [data-radix-tooltip-content] {
	transition-duration: 0ms;
}
```

Delay the first tooltip; subsequent peers show instantly with zero delay and zero animation.

### Origin-Aware Transforms

```css
.popover {
	transform-origin: var(--radix-dropdown-menu-content-transform-origin);
}
```

### Animation Values Proportional to Trigger

- Dialogs: Don't scale 0->1; use opacity fade + scale from **~0.8**
- Buttons: Don't scale 1->0.8; use **~0.96** or **~0.97**

### Reference Table

| Element          | Duration  | Easing      | Notes                          |
| ---------------- | --------- | ----------- | ------------------------------ |
| Button press     | Instant   | --          | `scale(0.97)` on `:active`     |
| Tooltip          | 150ms     | ease-out    | First delayed; peers instant   |
| Dropdown/popover | 150-200ms | ease-out    | Correct `transform-origin`     |
| Modal            | 200-300ms | ease-out    | Scale from ~0.8, fade opacity  |
| Toast enter      | 400ms     | ease        | CSS transitions, not keyframes |
| Page transition  | 200-300ms | ease-in-out | Consider View Transitions API  |
| Keyboard actions | 0ms       | none        | **Never animate**              |

## Typography

### Rendering

- MUST apply `-webkit-font-smoothing: antialiased`
- MUST apply `text-rendering: optimizeLegibility`
- MUST prevent iOS landscape resizing with `-webkit-text-size-adjust: 100%`
- MUST subset fonts based on content, alphabet, or relevant languages
- SHOULD preload critical fonts with `font-display: swap`

### Sizing & Weight

- MUST use `text-balance` for headings; `text-pretty` for body/paragraphs
- MUST use `font-variant-numeric: tabular-nums` for numbers, tables, timers
- SHOULD use `truncate` or `line-clamp-*` for dense UI
- SHOULD use fluid sizing via `clamp()` for responsive headings: `clamp(48px, 5vw, 72px)`
- SHOULD use font-weight 500-600 for medium headings
- NEVER use font weights below 400
- NEVER change font weight on hover/selected state (causes layout shift)
- NEVER modify `letter-spacing` (`tracking-*`) unless explicitly requested

### Content

- MUST use `...` character (not `...`)
- MUST use non-breaking spaces: `10&nbsp;MB`, `Cmd&nbsp;K`, brand names
- MUST use curly quotes (" ") over straight quotes (" ")
- SHOULD avoid widows/orphans with `text-wrap: balance`

### Avoiding AI Typography Slop

- NEVER default to Inter, Roboto, Open Sans, or Arial without justification
- SHOULD use distinctive fonts appropriate to the product's character: monospace families for technical tools, display faces for editorial, grotesques with personality for products
- SHOULD use extreme weight contrasts (100/200 vs 800/900) rather than safe middle choices (400 vs 600)
- SHOULD use bold size jumps (3x+) rather than timid increments (1.5x) for hierarchy

## Layout & Spacing

### Alignment

- MUST use deliberate alignment to grid/baseline/edges--no accidental placement
- MUST verify layouts on mobile (375px), laptop (1024px), and ultra-wide (1920px+, simulate at 50% zoom)
- MUST respect safe areas via `env(safe-area-inset-*)` for fixed elements
- MUST avoid unwanted scrollbars; fix overflows
- SHOULD use optical alignment; adjust +/-1px when perception beats geometry
- SHOULD balance icon/text lockups (weight, size, spacing, color)
- SHOULD use flex/grid over JS measurement for layout

### Spacing System

- MUST pick a base unit and stick to multiples (4px, 8px scale)
- MUST keep padding symmetrical unless there's a clear reason
- SHOULD use `size-*` for square elements instead of `w-*` + `h-*`

### Z-Index

- MUST use a fixed `z-index` scale (e.g., 10, 20, 30, 50)
- NEVER use arbitrary `z-*` values

### Viewport

- MUST use `h-dvh` not `h-screen`
- MUST account for notches and insets

## Color & Theming

### System Setup

- MUST set `color-scheme: dark` on `<html>` for dark themes
- MUST set explicit `background-color` and `color` on native `<select>` (Windows fix)
- MUST prevent theme switching from triggering unintended transitions (disable transitions temporarily during theme switch--otherwise every element animates when toggling dark mode)
- SHOULD set `<meta name="theme-color">` to match page background
- SHOULD use SVG favicon with `prefers-color-scheme` style tag
- SHOULD ensure zero flash on theme changes (script runs before framework hydration)

### Color Application

- MUST style document selection with `::selection`
- MUST meet contrast requirements--prefer APCA over WCAG 2
- MUST increase contrast on `:hover`/`:active`/`:focus`
- SHOULD use layered shadows (ambient + direct light)
- SHOULD use semi-transparent borders + shadows for crisp edges
- SHOULD ensure nested radii: child <= parent; concentric curves
- SHOULD tint borders/shadows/text toward background hue for consistency
- SHOULD limit accent color to one per view

### Advanced Color

- SHOULD consider LCH color space instead of HSL for perceptually uniform color--red and yellow at lightness 50 appear equally light in LCH but not in HSL
- SHOULD use minimal core variables per theme (base, accent, contrast) to enable automatic high-contrast themes
- SHOULD build surface hierarchy through opacity and calculated operations rather than arbitrary color choices
- SHOULD keep chrome color limited and neutral for a timeless appearance

### Forbidden Patterns

- NEVER use gradients unless explicitly requested
- NEVER use purple or multicolor gradients (quintessential "AI aesthetic")
- NEVER use glow effects as primary affordances
- NEVER use dark gradient colors that cause banding (use background images)

### Depth Strategy

Choose ONE and commit:

- **Borders-only**: Clean, technical. For dense tools.
- **Subtle shadows**: Soft lift. For approachable products.
- **Layered shadows**: Premium, dimensional. For cards needing presence.

Don't mix approaches within the same interface.

### Avoiding AI Color Slop

- NEVER use purple gradients on white backgrounds
- NEVER use timid, evenly-distributed palettes
- NEVER use solid white backgrounds with no atmosphere
- SHOULD commit to cohesive themes with dominant colors and sharp accents
- SHOULD layer CSS gradients, geometric patterns, and contextual effects

## Accessibility (WCAG 2.2)

### Keyboard & Focus

- MUST implement full keyboard support per WAI-ARIA APG patterns
- MUST show visible focus rings via `:focus-visible`; group with `:focus-within`
- MUST manage focus (trap, move, return) per APG patterns
- MUST make focusable elements in sequential lists navigable with up/down keys, deletable with Cmd+Backspace
- SHOULD use box-shadow for focus rings (respects border-radius unlike outline)
- NEVER use `outline: none` without visible focus replacement
- NEVER use positive `tabIndex` values (disrupts natural tab order)

```css
:focus-visible {
	box-shadow:
		0 0 0 2px var(--bg),
		0 0 0 4px var(--accent);
}
```

### Touch Targets

- MUST ensure hit targets >=24px (mobile >=44px)
- MUST expand hit area if visual target <24px
- MUST ensure no dead zones on checkboxes/radios; label+control share one hit target
- MUST ensure interactive elements in lists have no dead areas--increase padding

### Labels & Names

- MUST add `aria-label` to icon-only buttons and interactive elements
- MUST provide accessible names even when visuals omit labels
- MUST use accurate `aria-label`; mark decorative elements with `aria-hidden`
- MUST prefer native semantics (`button`, `a`, `label`, `table`, `dialog`) before ARIA

### Status & Feedback

- MUST use redundant status cues (not color-only); icons should have text labels
- MUST use polite `aria-live` for toasts and inline validation
- SHOULD use inline help first; tooltips as last resort
- NEVER add tooltips to disabled buttons (unreachable for keyboard users)

### Content (Accessibility)

- MUST ensure `<title>` matches current context
- MUST add `scroll-margin-top` on headings; include "Skip to content" link
- MUST use hierarchical `<h1>`-`<h6>` without skipping levels
- MUST design resilient layouts for user-generated content (short, average, very long)
- MUST use locale-aware formatting (`Intl.DateTimeFormat`, `Intl.NumberFormat`)
- MUST ensure gradient text unsets gradient on `::selection`

## Forms & Inputs

### Structure

- MUST wrap inputs with `<form>` to enable Enter submission
- MUST use appropriate `type` (`password`, `email`, etc.) and `inputmode`
- MUST use meaningful `name` attributes with correct `autocomplete` values
- MUST associate labels with inputs (for attribute or aria-labelledby)
- MUST position prefix/suffix decorations absolutely over input with padding, triggering focus

### Validation & Errors

- MUST allow incomplete form submission to surface validation errors
- MUST show errors inline next to fields; on submit, focus first error
- MUST link errors to fields using `aria-describedby`
- MUST set `aria-invalid="true"` on invalid fields

### Submission

- MUST keep submit enabled until request starts; then disable with spinner
- MUST show spinner on loading buttons while preserving original label
- MUST warn on unsaved changes before navigation
- MUST include idempotency key to prevent duplicate submissions

### Input Behavior

- MUST keep inputs hydration-safe (no lost focus/value); use `defaultValue` for uncontrolled
- MUST ensure compatibility with password managers and 2FA; allow pasting codes
- MUST trim values to handle trailing spaces from text expansion
- SHOULD disable `spellcheck` for emails, codes, usernames
- SHOULD end placeholders with `...` and show example pattern
- SHOULD prefer uncontrolled inputs; controlled inputs must be cheap per keystroke
- NEVER block paste in `<input>` or `<textarea>`

## Interaction Patterns

### State Management

- MUST reflect state in URL (deep-link filters, tabs, pagination, expanded panels)--anytime you reach for `useState`, consider whether it should be in the URL
- MUST restore scroll position on Back/Forward
- MUST use `<a>`/`<Link>` for navigation (supports Cmd/Ctrl/middle-click)
- MUST perform auth redirects server-side before client loads
- NEVER use `<div onClick>` for navigation

### Feedback

- MUST use `AlertDialog` for destructive or irreversible actions; or provide Undo window
- MUST display feedback relative to trigger (inline checkmark on copy--NOT a toast notification; highlight input on error)
- SHOULD use optimistic UI; update immediately; reconcile on server response; on failure, show error and roll back or provide Undo
- SHOULD use ellipsis (`...`) for options opening follow-ups ("Rename...") and loading states ("Loading...")

### Toggles & Controls

- MUST ensure toggles take immediate effect without confirmation
- MUST disable `user-select` on inner content of interactive elements
- MUST disable `pointer-events` on decorative elements (glows, gradients)
- MUST ensure anything that looks clickable is clickable

### Menus & Dropdowns

- SHOULD trigger dropdown menus on `mousedown` for immediate opening
- SHOULD use nested menus with "prediction cone" to prevent accidental closing when moving diagonally
- SHOULD delay first tooltip; subsequent peers show instantly

### Tactile Feedback Patterns

- SHOULD make touch elements "lift slightly" with a quick pulse on interaction
- SHOULD allow drag elements to "distort slightly" when dragged beyond view edges to resolve physical tension
- SHOULD use variable blur at scroll view edges that intensifies as content approaches screen boundary

### Touch Content Visibility

When fingers obstruct content:

- Text editing: magnifying loupe appears **above** touch point
- Loupe disappears when finger moves down and no longer covers caret
- Keyboard: enlarged key shows on press for confidence
- Sliders: gesture shouldn't cancel when moving away while pressing

### Implicit Input

The ultimate interface requires no input at all. Consider:

- Showing contextual information based on device state (time, location, motion)
- Adjusting interface accessibility based on usage context (driving, walking)
- Automatically adjusting brightness/contrast for environmental conditions
- Blurring sensitive content when app is in background/switcher

## Touch & Mobile

### Touch Handling

- MUST use `touch-action: manipulation` to prevent double-tap zoom
- MUST disable `touch-action` for custom pan/zoom gestures
- MUST use `overscroll-behavior: contain` in modals/drawers
- MUST disable text selection during drag; set `inert` on dragged elements
- MUST apply `muted` and `playsinline` to `<video>` for iOS autoplay
- SHOULD use `@media (hover: hover)` to prevent hover states flashing on touch press
- SHOULD set `-webkit-tap-highlight-color` to match design (disable default, but replace it)

```css
@media (hover: hover) {
	.button:hover {
		background: var(--hover);
	}
}
```

### Input Handling

- MUST set mobile `<input>` font-size >=16px to prevent iOS zoom on focus
- SHOULD avoid autofocus on mobile (opens keyboard, covers screen)
- NEVER disable browser zoom (`user-scalable=no`, `maximum-scale=1`)

## Performance

### Rendering

- MUST batch layout reads/writes; avoid reflows/repaints
- MUST track and minimize re-renders (React DevTools, React Scan)
- MUST profile with CPU/network throttling
- MUST measure reliably (disable extensions that skew runtime)
- SHOULD bypass React render lifecycle with refs for real-time DOM updates
- NEVER apply `will-change` outside an active animation
- NEVER use `useEffect` for anything expressible as render logic

### Loading

- MUST target <500ms for mutations (`POST`/`PATCH`/`DELETE`)
- MUST virtualize large lists (>50 items)
- MUST preload above-fold images; lazy-load the rest
- MUST prevent CLS with explicit image dimensions
- MUST match skeletons to final content layout
- MUST pause or unmount off-screen auto-playing videos on iOS
- SHOULD use `<link rel="preconnect">` for CDN domains
- SHOULD preload critical fonts with `font-display: swap`
- SHOULD adapt to user's hardware/network capabilities
- SHOULD test on iOS Low Power Mode and macOS Safari

## States & Content

### Required States

Every component/page MUST handle:

- **Default**: Normal state
- **Loading**: Skeleton or spinner (matching final layout)
- **Empty**: Prompt to create with optional templates
- **Error**: Clear message with recovery path
- **Disabled**: Visual indication without relying on color alone

- MUST design empty, sparse, dense, and error states--no dead ends
- MUST give empty states one clear next action

### Feedback States

Every interactive element MUST have:

- **Hover**: Increased contrast/emphasis
- **Focus**: Visible focus ring
- **Active/Pressed**: scale(0.97) or equivalent
- **Disabled**: Reduced opacity, no pointer cursor

## Design Tokens

### Naming Convention

Token names should reflect the product's world:

- `--ink` and `--parchment` evoke a world
- `--gray-700` and `--surface-2` evoke a template

Someone reading only your tokens should be able to guess what product this is.

### Consistency

- MUST use existing theme or Tailwind color tokens before introducing new ones
- MUST maintain consistent spacing scale throughout
- MUST use consistent border-radius scale (sharper = technical, rounder = friendly)

## Modern CSS Techniques

### View Transitions API

```css
/* Opt-in to cross-document transitions */
@view-transition {
	navigation: auto;
}

/* Assign transition names */
.hero-image {
	view-transition-name: hero;
	contain: layout;
}

/* Customize the transition */
::view-transition-old(root),
::view-transition-new(root) {
	animation-duration: 0.3s;
}
```

- Avoid lengthy animations (affects INP Core Web Vital)
- Use `contain: layout` on transitioning elements
- Set `animation-fill-mode: forwards` to prevent flicker

### Scroll-Driven Animations

```css
.card {
	animation: reveal linear both;
	animation-timeline: view();
	animation-range: entry 0% entry 100%;
}

@keyframes reveal {
	from {
		opacity: 0;
		transform: scale(0.9);
	}
	to {
		opacity: 1;
		transform: scale(1);
	}
}

/* Progress bar tied to scroll */
.progress-bar {
	transform-origin: left;
	animation: scaleProgress linear both;
	animation-timeline: scroll(root);
}
```

### Container Queries

```css
.card-container {
	container-type: inline-size;
	container-name: card;
}

@container card (width > 400px) {
	.card-title {
		font-size: 1.5rem;
	}
	.card-content {
		flex-direction: row;
	}
}

/* Container units */
.component {
	padding: 2cqi; /* 2% of container inline size */
	font-size: 3cqw; /* 3% of container width */
}
```

### Animate to Auto Height (2024+)

```css
html {
	interpolate-size: allow-keywords;
}

.accordion-content {
	height: 0;
	overflow: hidden;
	transition: height 0.3s;
}

.accordion.open .accordion-content {
	height: auto; /* Now animatable! */
}
```

## Review Checklist

Before shipping, run these checks:

### The Swap Test

If you swapped the typeface for your usual one, would anyone notice? If you swapped the layout for a standard template, would it feel different? The places where swapping wouldn't matter are the places you defaulted.

### The Squint Test

Blur your eyes. Can you still perceive hierarchy? Is anything jumping out harshly? Craft whispers--nothing should scream.

### The Signature Test

Can you point to five specific elements where your design signature appears? Not "the overall feel"--actual components. A signature you can't locate doesn't exist.

### The Token Test

Read your CSS variables out loud. Do they sound like they belong to this product's world, or could they belong to any project?

### Technical Checklist

#### Accessibility

- [ ] All images have alt text (meaningful or empty for decorative)
- [ ] All form inputs have labels
- [ ] All icon-only buttons have `aria-label`
- [ ] All buttons have accessible names
- [ ] Focus states visible on all interactive elements (`:focus-visible`)
- [ ] Color is not the only indicator of state
- [ ] Color contrast >=4.5:1 (prefer APCA)
- [ ] Keyboard navigation works for all flows
- [ ] Heading levels sequential
- [ ] Touch targets >=44x44px on mobile

#### Animation

- [ ] Duration <=200ms for interactions
- [ ] Honors `prefers-reduced-motion`
- [ ] Only animates `transform` and `opacity`
- [ ] Interruptible by user input
- [ ] Correct `transform-origin`
- [ ] No animation on high-frequency actions

#### Visual Polish

- [ ] Layered shadows (ambient + direct light)
- [ ] Nested radii (child <= parent, concentric)
- [ ] Optical alignment (+/-1px adjustments)
- [ ] No dead zones between interactive elements
- [ ] Theme switching doesn't trigger transitions
- [ ] `font-variant-numeric: tabular-nums` for numbers

#### Forms

- [ ] Enter submits when appropriate
- [ ] Labels on all inputs
- [ ] Errors shown next to fields (not just toasts)
- [ ] Submit enabled until submission starts
- [ ] Placeholders end with ellipsis
- [ ] Paste never blocked

#### Performance

- [ ] No layout animations on large surfaces
- [ ] No `will-change` outside active animations
- [ ] Images have explicit dimensions
- [ ] Lists >50 items are virtualized
- [ ] Fonts preloaded and subset
- [ ] Network requests <500ms

#### Mobile

- [ ] Touch targets >=44px
- [ ] Input font-size >=16px
- [ ] No horizontal scroll at 375px
- [ ] Safe areas respected for fixed elements

## Common Anti-Patterns

### Visual

| Bad                            | Good                          |
| ------------------------------ | ----------------------------- |
| Emoji icons                    | SVG icons (Heroicons, Lucide) |
| Purple/multicolor gradients    | Subtle, purposeful color      |
| Glow effects as affordances    | Borders, shadows, contrast    |
| Dramatic drop shadows          | Subtle layered shadows        |
| Pure white cards on colored bg | Tinted or transparent cards   |
| Thick decorative borders       | Subtle structural borders     |
| Inter/Roboto/Arial by default  | Distinctive, justified fonts  |
| Solid white bg, no atmosphere  | Layered gradients, texture    |

### Interaction

| Bad                                 | Good                            |
| ----------------------------------- | ------------------------------- |
| `<div onClick>` for navigation      | `<a>` or `<Link>`               |
| Blocking paste in inputs            | Always allow paste              |
| Disabled button tooltips            | Enabled button with explanation |
| Weight change on hover              | Color/opacity change on hover   |
| Animation on every interaction      | Animation for novelty only      |
| Custom modal with `<div>`           | Native `<dialog>` element       |
| `outline: none` without replacement | `box-shadow` focus ring         |

### Layout

| Bad                        | Good                         |
| -------------------------- | ---------------------------- |
| `h-screen`                 | `h-dvh`                      |
| Arbitrary `z-index` values | Fixed z-index scale          |
| `transition: all`          | Explicit property list       |
| Scale from 0               | Scale from 0.93+             |
| Mixed depth strategies     | One consistent approach      |
| "Frankenstein" layouts     | Clear hierarchy, one goal    |
| Giant stat cards           | Dense, useful information    |
| Repeated same info         | Each element earns its space |

## Quick Reference Tables

### Animation Timing

| Context         | Duration  | Easing      |
| --------------- | --------- | ----------- |
| Button press    | 100ms     | ease-out    |
| Tooltip         | 150ms     | ease-out    |
| Dropdown        | 150-200ms | ease-out    |
| Modal           | 200-300ms | ease-out    |
| Page transition | 200-300ms | ease-in-out |

### Touch Targets

| Context  | Minimum Size                  |
| -------- | ----------------------------- |
| Desktop  | 24px                          |
| Mobile   | 44px                          |
| Dense UI | 32px (with expanded hit area) |

### Contrast Ratios

| Content            | Minimum Ratio |
| ------------------ | ------------- |
| Body text          | 4.5:1         |
| Large text (18pt+) | 3:1           |
| UI components      | 3:1           |
| Focus indicators   | 3:1           |

### Font Sizes

| Context       | Minimum                  |
| ------------- | ------------------------ |
| Body text     | 16px                     |
| Mobile inputs | 16px (prevents iOS zoom) |
| Small text    | 12px                     |
| Captions      | 11px                     |

## References & Inspiration

This document synthesizes principles and patterns from practitioners who've spent years refining interfaces used by millions. Their published writings, open-source tools, and design systems informed every section.

**People**

- Emil Kowalski -- Animation timing rules, button scale patterns, tooltip sequencing, blur bridging technique. Creator of Sonner.
- Rauno Freiberg -- Frequency x novelty matrix, interaction design metaphors, touch content visibility, implicit input. Web Interface Guidelines author.
- Paco Coursey -- Composable unstyled primitives (cmdk), zero-flash theme switching (next-themes), native-class web app philosophy.
- Adam Wathan -- Constraint-based design systems, component extraction over class abstraction. Creator of Tailwind CSS.

**Design Systems & Products**

- Linear -- LCH color space, surface hierarchy through opacity, tactile feedback patterns, meticulous alignment, variable blur at scroll edges.
- Vercel -- Web Interface Guidelines, design system principles, agent-focused frontend guidance.
- shadcn/ui -- Open-code component philosophy, two-layer architecture (Radix + Tailwind), composition over configuration.
- Arc Browser -- Native-feeling web interfaces, interaction design craft.

**Standards & Resources**

- [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/patterns/)
- [WCAG 2.2 Guidelines](https://www.w3.org/TR/WCAG22/)
- [APCA Contrast Calculator](https://apcacontrast.com/)
- [Web Interface Guidelines](https://github.com/raunofreiberg/interfaces)
- [easings.co](https://easings.co/) -- Custom easing curves
- [Vercel Web Interface Guidelines](https://vercel.com/design/guidelines)
