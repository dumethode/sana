# Sana: Design System

Every UI task in this repo follows this file. Tokens live in `lib/core/theme/`; widgets never hard-code colours, sizes or fonts.

## 1. Direction

A maintenance work order, not a social feed. Each report is a **ticket**: a stub on the left carrying the category, a reference code in monospace, and a status that moves along a rail. Calm, legible, flat. Colour is reserved for meaning (category and status), never decoration.

## 2. Colour

| Token | Light | Dark | Use |
|---|---|---|---|
| canvas | `#F4F2ED` | `#0E1116` | Page background (warm paper) |
| surface | `#FFFFFF` | `#161A21` | Cards, sheets, inputs |
| ink | `#0B1F3A` | `#E7ECF3` | Primary text, headings |
| inkMuted | `#5A6373` | `#9AA4B2` | Secondary text |
| line | `#E2DED5` | `#262C36` | 1 px borders, dividers |
| signal | `#C2410C` | `#FF6A33` | The single action colour: Report button, primary buttons, focus |
| onSignal | `#FFFFFF` | `#0E1116` | Text and icons on signal (5.2:1 light, 6.6:1 dark) |

Status colours: Submitted `#64748B`, Acknowledged `#4F46E5`, In progress `#C27803`, Resolved `#15803D`, Rejected `#B42318`.

Category colours: Water `#0284C7`, Electricity `#CA8A04`, Facilities `#8B5E34`, Sanitation `#0F766E`, Safety `#DC2626`, Internet `#7C3AED`, Other `#475569`.

Chips put text on a 12% tint of their own colour. The raw colours do not all pass on a tint (Electricity yellow is 2.6:1), so text and icons use `SanaPalette.onTint`: the colour darkened 30% in light mode or lightened 35% in dark mode. The weakest pair is 4.8:1, above WCAG 2.2 AA (4.5:1).

## 3. Type

| Role | Font | Size / weight |
|---|---|---|
| Display (screen titles, stat numbers) | Space Grotesk | 28 / 700, 22 / 600 |
| Title (card titles) | Space Grotesk | 17 / 600 |
| Body | IBM Plex Sans | 15 / 400, line height 1.45 |
| Label (chips, buttons) | IBM Plex Sans | 13 / 600 |
| Code (reference codes, timestamps, overlines) | IBM Plex Mono | 12 / 500, letter-spacing 0.6 |

Fonts are bundled in `assets/fonts` (SIL OFL) so the app renders identically offline.

## 4. Shape and space

- Spacing scale: 4, 8, 12, 16, 20, 24, 32.
- Radius: 14 for cards and sheets, 12 for inputs and buttons, 999 for pills.
- No drop shadows. Separation comes from a 1 px `line` border and the canvas/surface contrast.
- Minimum touch target 48 x 48.

## 5. Signature components

- **Ticket card**: left stub (category colour tint + icon), body with mono reference code, title, location, status pill, severity tag, "affected" count and relative time. A "Syncing" chip appears while a write is still pending.
- **Status rail**: four stops (Submitted, Acknowledged, In progress, Resolved). Rejected replaces the rail with a single red banner and the staff note.
- **Timeline**: vertical list of events with mono timestamps and the actor's role.
- **Stat tile**: large Space Grotesk number, mono overline label.

## 6. Layout

- < 720 px: bottom navigation bar, single column.
- >= 720 px (landscape phones, tablets): navigation rail, two-column ticket grid, form constrained to 640 px.

## 7. States (required on every data screen)

Loading uses skeleton tickets, not spinners. Empty states explain what will appear and offer the next action. Errors show the plain-language reason and a Retry button. Destructive actions confirm first. Every async button shows its own progress and is disabled while running.

## 8. Voice

Short, direct, no exclamation marks. Errors say what happened and what to do next ("Use your ALU email to sign up", not "Invalid input").
