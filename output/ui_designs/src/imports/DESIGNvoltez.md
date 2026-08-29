---
name: Vibrant Professionalism
colors:
  surface: '#f8f9fa'
  surface-dim: '#d9dadb'
  surface-bright: '#f8f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f5'
  surface-container: '#edeeef'
  surface-container-high: '#e7e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#404943'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#707973'
  outline-variant: '#bfc9c1'
  surface-tint: '#2c694e'
  primary: '#0f5238'
  on-primary: '#ffffff'
  primary-container: '#2d6a4f'
  on-primary-container: '#a8e7c5'
  inverse-primary: '#95d4b3'
  secondary: '#485f84'
  on-secondary: '#ffffff'
  secondary-container: '#bbd3fd'
  on-secondary-container: '#445a7f'
  tertiary: '#5f4200'
  on-tertiary: '#ffffff'
  tertiary-container: '#7e5800'
  on-tertiary-container: '#ffd388'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b1f0ce'
  primary-fixed-dim: '#95d4b3'
  on-primary-fixed: '#002114'
  on-primary-fixed-variant: '#0e5138'
  secondary-fixed: '#d5e3ff'
  secondary-fixed-dim: '#b0c7f1'
  on-secondary-fixed: '#001b3c'
  on-secondary-fixed-variant: '#30476a'
  tertiary-fixed: '#ffdea9'
  tertiary-fixed-dim: '#ffba27'
  on-tertiary-fixed: '#271900'
  on-tertiary-fixed-variant: '#5e4100'
  background: '#f8f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  display-lg:
    fontFamily: Outfit
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Outfit
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Outfit
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Outfit
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-bold:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base-unit: 4px
  margin-mobile: 20px
  gutter-mobile: 16px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 24px
  stack-xl: 40px
---

## Brand & Style

The design system is engineered for a high-impact mobile experience that balances professional reliability with a refreshing, energetic personality. It targets users who value efficiency but appreciate a UI that feels alive and tactile.

The aesthetic follows a **High-Contrast Modern** direction. It utilizes bold saturations and deep value shifts to ensure every interactive element is unmistakable. By combining the structured discipline of corporate SaaS with the vibrant energy of consumer lifestyle apps, the system evokes a sense of "trustworthy vitality." White space is used generously to prevent the bold color palette from becoming overwhelming, ensuring a clean, accessible interface.

## Colors

The palette is anchored by **Leaf Green** (#2D6A4F) for primary actions, signaling growth and success. **Ocean Blue** (#1D3557) provides a professional foundation, used for navigation components and heavy headers to ground the design.

**Marigold** (#FFB703) acts as a high-visibility accent for highlights and warnings, while **Coral** (#E76F51) is reserved for secondary calls-to-action or status indicators. To maintain professional clarity, use a neutral base of off-whites and cool grays for background surfaces, ensuring the vibrant primary colors serve as functional signposts rather than mere decoration.

## Typography

This design system utilizes a dual-font strategy to maximize both character and readability. **Outfit** is used for headlines; its geometric construction and wide apertures provide a friendly, modern presence. **Inter** is used for all body copy and UI labels, selected for its exceptional legibility at small sizes and its neutral, systematic feel.

For mobile-specific views, large display type should scale down significantly to prevent awkward line breaks. Tracking (letter-spacing) is slightly tightened on large headings to maintain a cohesive visual block, while small labels use increased tracking to improve glanceability.

## Layout & Spacing

The layout follows a **Fluid Grid** model optimized for touch-first interaction. A 4px baseline grid governs all vertical rhythm, ensuring consistent spacing between text and elements.

On mobile, a standard 4-column grid is used with 20px outer margins to provide a generous "safe zone" for thumbs. For tablet layouts, this expands to an 8-column grid. Components should use the stack-md (16px) spacing as the default gap for most UI groupings to maintain a clean, airy feel that facilitates easy scanning.

## Elevation & Depth

To match the high-contrast professional aesthetic, depth is communicated through **Tonal Layers** supplemented by **Ambient Shadows**. Surfaces are primarily flat or use very subtle gradients, with elevation indicated by distinct shifts in background color (e.g., a white card on a light gray background).

When shadows are required for floating elements like FABs (Floating Action Buttons) or Modals, they must be highly diffused and slightly tinted with the secondary Ocean Blue (#1D3557) at very low opacity (8-12%). This "colored shadow" technique prevents the UI from looking muddy and maintains the vibrant color story of the design system.

## Shapes

The shape language is defined by a consistent **Rounded** (Level 2) approach. This 12px-16px radius creates a friendly, approachable interface that feels comfortable in the hand.

- **Standard Components (Buttons, Inputs):** 12px radius.
- **Containers (Cards, Modals):** 16px (rounded-lg) to 24px (rounded-xl) radius.
- **Small Elements (Chips, Tags):** Fully rounded/pill-shaped for maximum distinction from functional buttons.

## Components

### Buttons
Primary buttons use the Leaf Green background with white text. Secondary buttons use a thick 2px border of Ocean Blue with Ocean Blue text. Ensure a minimum height of 48px for all touch targets.

### Input Fields
Inputs utilize a light gray background with a 1px border that shifts to Ocean Blue on focus. Labels should stay visible (floating or top-aligned) to aid accessibility.

### Cards
Cards are white with a subtle 1px neutral border or a soft ambient shadow. They should always feature a 16px corner radius to distinguish them from the page background.

### Chips & Tags
Used for filtering and categorization. Use the Marigold or Coral palettes at 10-15% opacity with high-contrast text for a "soft highlight" effect that doesn't compete with primary actions.

### Lists
List items should be separated by clear 1px dividers or generous vertical spacing (16px). Use Ocean Blue for icons within lists to maintain a professional, cohesive look.

### Selection Controls
Checkboxes and Radios should inherit the Leaf Green color when active. The hit area for these controls must be at least 44x44px, even if the visual icon is smaller.