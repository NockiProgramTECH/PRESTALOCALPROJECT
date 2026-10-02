---
name: Warm Kinetic Modern
colors:
  surface: '#fbf9f7'
  surface-dim: '#dbdad8'
  surface-bright: '#fbf9f7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3f1'
  surface-container: '#efedec'
  surface-container-high: '#eae8e6'
  surface-container-highest: '#e4e2e0'
  on-surface: '#1b1c1b'
  on-surface-variant: '#564338'
  inverse-surface: '#30302f'
  inverse-on-surface: '#f2f0ee'
  outline: '#8a7266'
  outline-variant: '#ddc1b3'
  surface-tint: '#9a4600'
  primary: '#9a4600'
  on-primary: '#ffffff'
  primary-container: '#ff8a3d'
  on-primary-container: '#682d00'
  inverse-primary: '#ffb68d'
  secondary: '#545f73'
  on-secondary: '#ffffff'
  secondary-container: '#d5e0f8'
  on-secondary-container: '#586377'
  tertiary: '#006c49'
  on-tertiary: '#ffffff'
  tertiary-container: '#22c087'
  on-tertiary-container: '#00482f'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbc9'
  primary-fixed-dim: '#ffb68d'
  on-primary-fixed: '#321200'
  on-primary-fixed-variant: '#763300'
  secondary-fixed: '#d8e3fb'
  secondary-fixed-dim: '#bcc7de'
  on-secondary-fixed: '#111c2d'
  on-secondary-fixed-variant: '#3c475a'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#fbf9f7'
  on-background: '#1b1c1b'
  surface-variant: '#e4e2e0'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.05em
  currency-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 20px
  currency-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '800'
    lineHeight: 30px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-md: 1.5rem
  gutter-lg: 2rem
  margin: 1rem
  margin-md: 1.5rem
  margin-lg: 2.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.25rem
---

## Brand & Style

This design system establishes a high-trust, vibrant on-demand marketplace tailored for everyday urban and regional mobility, trade, and artisan services in West Africa. The visual narrative combines the energetic hospitality of warm sunlit tones with rigorous fintech-grade clarity.

### Personality & Tone
- **Warm & Welcoming:** Energetic citrus primary tones grounded by calming, organic sand surfaces that eliminate sterile digital coldness.
- **Resilient & Trustworthy:** High-contrast structural slate anchors the interface, conveying institution-grade legitimacy for transactions, bookings, and verified identity.
- **Agile & Human:** Generous touch areas, immediate visual feedback, and clear micro-status indicators ('Disponible', 'Vérifié') that build mutual reliability between clients and independent service providers.

### Design Movement
Modern Soft-Tactile Corporate: Employs gentle off-white container elevation, airy spacing, balanced radii, and high-visibility status cues optimized for outdoor mobile use under bright sunlight.

## Colors

The palette balances vibrancy with structural legibility across outdoor lighting conditions common in West African usage contexts.

### Color Hierarchy & Roles
- **Primary (`#FF8A3D`):** Active interactive triggers, main action buttons, accent banners, and urgent notification dots.
- **Secondary (`#1E293B`):** Deep navy slate dedicated to primary typography, core structural borders, icons, navigation headers, and grounding card frames.
- **Tertiary (`#10B981`):** Trust and status anchor. Dedicated to 'Vérifié' artisan badges, 'Disponible' live status indicators, confirmed bookings, and wallet balance credits.
- **Neutral Canvas (`#FBF9F7`):** Warm Sahara sand canvas that reduces eye strain compared to harsh blue-white screens.
- **Surface Elevation (`#FFFFFF`):** High-clarity white card backgrounds providing clean separation against the sand canvas.
- **Borders & Dividers (`#EAE3DB`):** Subtle warm-tinted borders replacing neutral gray to maintain atmospheric coherence.
- **Warning & Attention (`#F59E0B`):** Pending approvals, quote delays, or transit milestones.
- **Destructive (`#EF4444`):** Booking cancellations, critical alerts, and payment errors.

## Typography

Plus Jakarta Sans governs the entire typographic system, delivering geometric clarity, open apertures, and exceptional readability on low-cost and high-density mobile screens alike.

### Typographic Rules & Localization
- **Currency Presentation:** All pricing must explicitly append or format the regional currency as `FCFA` (e.g., `12 500 FCFA`), using non-breaking thin spaces between thousands.
- **Visual Weight:** Use bold weights (`700` and `800`) on price points, category headers, and technician ratings to facilitate fast scanning while in transit.
- **Language Clarity:** Optimized for French language strings with balanced line heights to accommodate multi-syllable phrases and accents without clipping.

## Layout & Spacing

The layout is built around a mobile-first fluid grid optimized for one-handed operation, moving toward structured 12-column layouts on larger screens.

### Grid & Breakpoint Model
- **Mobile (<640px):** Single-column layout with fixed outer margin (`margin`: `1rem`). Cards stack with a minimum vertical gap of `space-md` (1rem). Touch interaction zones target a minimum height of 48px.
- **Tablet (640px - 1024px):** 6-column fluid grid with 1.5rem margins and gutters. Booking summaries, provider listings, and categories adopt 2-column card layouts.
- **Desktop (>1024px):** 12-column grid capped at 1200px container width. Utilizes a persistent left-hand or sticky navigation shell alongside a split provider-detail/map view.

### Rhythmic Padding
- Component interior padding defaults to `space-md` for standard cards and `space-lg` for primary hero banners and promotional carousels.

## Elevation & Depth

This design system avoids heavy shadows, opting for subtle ambient diffusion tinted with warm umber to mirror real-world outdoor lighting.

### Elevation Hierarchy
- **Level 0 (Canvas):** Ground layer (`#FBF9F7`). Flat background without shadow or outline.
- **Level 1 (Default Containers):** Clean cards and interactive modules (`#FFFFFF`) with a 1px border (`#EAE3DB`) and a soft ambient drop: `box-shadow: 0 1px 3px rgba(30, 41, 59, 0.04), 0 4px 12px rgba(255, 138, 61, 0.03)`.
- **Level 2 (Floating Overlays & Active State):** Provider quick-select sheets, search bars, and active navigation bars: `box-shadow: 0 8px 24px rgba(30, 41, 59, 0.08), 0 2px 6px rgba(255, 138, 61, 0.05)`.
- **Level 3 (Modals & Bottom Drawers):** Critical booking confirmations, drawer dialogs: `box-shadow: 0 16px 40px rgba(30, 41, 59, 0.16)`.

## Shapes

The interface embraces organic, friendly curvature (`rounded-2xl` for containers) balanced with functional discipline.

### Radius Token Mapping
- **Input Fields & Small Buttons:** Rounded at `0.75rem` (12px) to ensure sharp interior tap targets.
- **Standard Cards & Surfaces:** Rounded at `1rem` to `1.5rem` (16px to 24px, representing `rounded-2xl`) to provide a tactile, safe, and modern mobile app feel.
- **Badges, Tags & Pill Action Triggers:** Fully rounded (`9999px`) to distinguish categorical metadata from structural content containers.

## Components

### Buttons
- **Primary:** Solid `#FF8A3D` with white text, font weight 600, height 48px on mobile. Pressed state shifts to `#E07228`.
- **Secondary:** Transparent fill with 1.5px solid `#1E293B` border and `#1E293B` text. Hover/Tap fills with `#1E293B` with `#FFFFFF` text.
- **Tertiary / Ghost:** `#FBF9F7` background with `#FF8A3D` text for low-friction actions (e.g., 'Voir plus').

### Chips & Badges
- **Status 'Disponible':** Soft pill with `#ECFDF5` background, `#065F46` label, preceded by a pulsing 8px solid emerald circle (`#10B981`).
- **Badge 'Vérifié':** `#ECFDF5` background with an integrated emerald shield icon and `#047857` micro-typography.
- **Service Categories:** White rounded-xl chips with a 1px border (`#EAE3DB`), 8px icon, and navy text (`#1E293B`).

### Provider Cards
- Crisp `#FFFFFF` surface with `1.5rem` (`rounded-2xl`) border radius, bounded by `#EAE3DB`.
- Layout: Provider portrait (56px rounded-xl), display name, star rating with warm orange fill, 'Vérifié' micro-badge, base pricing prominently framed in `FCFA`, and a high-contrast 'Réserver' action trigger.

### Inputs & Search
- Generous text fields (48px height) with light sand placeholder text, `#1E293B` user inputs, and a warm focus ring: `2px solid #FF8A3D` with a subtle 4px glow.
- Location inputs feature dedicated geo-pin markers and native geolocation trigger pills.

### Lists & Activity Feeds
- Hairline dividers tinted in `#EAE3DB`.
- High-contrast timestamp strings and clear two-line summaries: title in navy semibold, secondary details in muted slate (`#64748B`).