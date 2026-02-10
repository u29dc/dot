# Craft Checklist

Run this before shipping UI changes.

## Accessibility

- [ ] All non-decorative images have meaningful `alt` text.
- [ ] All inputs have visible labels and correct associations.
- [ ] Icon-only controls have accessible names.
- [ ] Focus styles are visible on all interactive controls.
- [ ] Keyboard-only navigation completes critical user flows.
- [ ] Heading structure is sequential and meaningful.
- [ ] Color is not the only status indicator.
- [ ] Contrast meets minimums (prefer APCA; WCAG minimum fallback).
- [ ] Touch targets meet minimum size constraints.

## Motion

- [ ] Interaction animations stay under 200ms.
- [ ] No animation exceeds 300ms.
- [ ] `prefers-reduced-motion` is honored.
- [ ] Only compositor-friendly properties animate.
- [ ] High-frequency/keyboard actions are not animated.
- [ ] Transform origins match physical source of motion.

## Visual Quality

- [ ] Layering strategy is consistent (border/shadow depth model).
- [ ] Nested radius values are coherent.
- [ ] Numeric UI uses tabular numerals.
- [ ] Theme switching does not animate entire UI unexpectedly.
- [ ] Layout has no dead zones or accidental whitespace traps.

## Forms

- [ ] Enter submission works where expected.
- [ ] Inline errors are visible and linked to fields.
- [ ] Submit button disables only after request starts.
- [ ] Paste is not blocked.
- [ ] Input semantics (`type`, `name`, `autocomplete`) are correct.

## Performance

- [ ] Media has explicit dimensions (CLS safe).
- [ ] Large lists are virtualized.
- [ ] No long-lived `will-change` declarations.
- [ ] Off-screen autoplay media is paused/unmounted.
- [ ] Measured under realistic throttling, not only on fast local hardware.

## Mobile

- [ ] No horizontal scroll at 375px viewport.
- [ ] Input text size is >=16px on mobile.
- [ ] Safe areas are respected for fixed elements.
- [ ] Hover styles are gated by hover-capable media query.
