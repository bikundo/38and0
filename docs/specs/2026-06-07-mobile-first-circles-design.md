# Mobile-First Layout and Circle Lineup Badges Design

Make the draft layout fully mobile-friendly and transition the pitch view from standard rectangular cards to modern circular badges styled similarly to standard sports layout visualizers.

## User Review Required

> [!NOTE]
> The draft controls/pool list will stack on top on mobile viewports so users can interact with spins and drafting without constantly scrolling past the pitch container.
> The pitch visualizer will adapt to smaller screen sizes and scale down circle elements using Tailwind utility boundaries.

## Proposed Changes

### Lineup Pitch Component

#### [MODIFY] [game_live.ex](file:///lib/invincibles_web/live/game_live.ex)

1. Introduce `@position_descriptions` to map position atoms to human-readable sub-labels (e.g. `st` -> `"Striker"`).
2. Change the layout `<main>` container and internal structures to use Tailwind order utilities (`order-1` on draft controls, `order-2` on pitch area for mobile).
3. Replace the inner card elements with circular badges:
   * **Empty slot**: Dashed outer border, text abbreviation, dark translucent badge with the position category description underneath.
   * **Occupied slot**: Solid rose/coral colored circle, text abbreviation, dark translucent badge with the player's truncated last name underneath.
4. Implement a clean `truncate_name/1` helper to extract the last name and limit length to fit gracefully in the sub-label bubble.

## Verification Plan

### Manual Verification
* Access the app in browser.
* Toggle mobile responsive mode in dev tools. Verify that Draft Controls appear on top and Soccer Pitch below it.
* Verify that on desktop, Soccer Pitch is on the left and Draft Controls are on the right.
* Verify empty and occupied circle styles. Empty should show abbreviation & description (e.g. "Striker" under "ST"). Occupied should show abbreviation & name (e.g. "McMana..." under "SM" in a solid Rose/Coral background circle).
