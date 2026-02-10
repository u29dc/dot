# Craft Anti-Patterns

Use this matrix during review.

## Visual

| Bad                                          | Better                                        |
| -------------------------------------------- | --------------------------------------------- |
| Purple/multicolor gradient default aesthetic | Purposeful palette tied to product identity   |
| Glow-heavy affordances                       | Contrast, hierarchy, spacing, and motion cues |
| Generic system font with no rationale        | Typeface chosen to match product character    |
| Flat white background with no structure      | Layered surfaces and intentional depth        |
| Random z-index escalation                    | Fixed z-index ladder and documented layers    |

## Interaction

| Bad                                           | Better                                                       |
| --------------------------------------------- | ------------------------------------------------------------ |
| `<div onClick>` for navigation                | Semantic `<a>` / framework `<Link>`                          |
| Disabled button with tooltip-only explanation | Enabled action with inline guidance or clear prerequisite    |
| Weight-changing hover states causing shift    | Color/opacity/background emphasis without reflow             |
| Animation on every frequent action            | Animation reserved for novelty, orientation, or confirmation |
| Blocking paste in inputs                      | Always allow paste; validate and sanitize afterward          |

## Motion

| Bad                                | Better                                 |
| ---------------------------------- | -------------------------------------- |
| `transition: all`                  | Explicit property transitions          |
| Scale from `0`                     | Scale from `0.96+` with opacity        |
| Layout property animations         | Transform/opacity-only motion          |
| Long, decorative transitions       | Fast, intent-aligned feedback          |
| Ignoring reduced-motion preference | Alternate reduced/disabled motion path |

## Layout and Responsiveness

| Bad                               | Better                                           |
| --------------------------------- | ------------------------------------------------ |
| `h-screen` on mobile surfaces     | `h-dvh` with safe-area awareness                 |
| Pixel-perfect desktop-only layout | Responsive behavior validated at key breakpoints |
| Arbitrary spacing everywhere      | Fixed spacing scale and rhythm                   |
| Overflow ignored until QA         | Early overflow/scrollbar checks                  |
| Dead click zones in list rows     | Entire actionable row has continuous hit area    |
