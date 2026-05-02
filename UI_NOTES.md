# MetaCasa — UI/UX Design System Notes

## Overview
This document describes the visual design system implemented in MetaCasa. All visual tokens are defined in `src/index.css` as plain CSS classes, compatible with Tailwind v4.

---

## Color Tokens (dark theme)

| Role | Value | Usage |
|------|-------|-------|
| Background | `#09090b` | App background |
| Surface | `rgba(24,24,27,0.65)` | Cards, panels |
| Surface inset | `rgba(9,9,11,0.5)` | Inner containers |
| Border | `rgba(255,255,255,0.07)` | Subtle dividers |
| Primary | `#6366f1` (indigo-500) | CTAs, active states |
| Success | `#10b981` (emerald-500) | Income, positive |
| Danger | `#f43f5e` (rose-500) | Expenses, errors |
| Warning | `#f59e0b` (amber-500) | Warnings, fixed items |
| Text primary | `#fafafa` | Main text |
| Text muted | `#71717a` | Secondary text |
| Text dim | `#3f3f46` | Disabled / placeholder |

---

## Typography Scale

| Class | Size | Weight | Usage |
|-------|------|--------|-------|
| `.text-display` | clamp(1.75rem–2.5rem) | 900 | Hero amounts (balance) |
| `.text-h1` | clamp(1.25rem–1.75rem) | 900 | Tab headers |
| `.text-h2` | clamp(1rem–1.25rem) | 800 | Section headers |
| `.text-amount` | clamp(1.35rem–1.75rem) | 900 | Card amounts |
| `.text-label` | 11px / uppercase / 700 | — | Section labels |
| Tailwind `text-sm` | 14px | — | Body text |
| Tailwind `text-xs` | 12px | — | Captions |

---

## Card System

| Class | Description |
|-------|-------------|
| `.mc-card` | Standard card with glass effect and border |
| `.mc-card-sm` | Smaller rounded card (20px radius) |
| `.mc-card-inset` | Dark inset container (inputs, toggles) |
| `.glass-card` | Indigo tinted glassmorphism card |
| `.glass-success` | Emerald tinted glassmorphism card |
| `.glass-danger` | Rose tinted glassmorphism card |
| `.glass-warning` | Amber tinted glassmorphism card |

### Usage
```jsx
// Standard card
<div className="mc-card px-5 py-4">...</div>

// Accent card
<div className="glass-success px-5 py-4">...</div>

// Inset (for inputs/toggles)
<div className="mc-card-inset p-4">...</div>
```

---

## Button System

| Class | Description |
|-------|-------------|
| `.btn-primary` | Indigo filled, uppercase, 900 weight |
| `.btn-secondary` | Zinc ghost with border |
| `.btn-ghost` | Text only, hover state |
| `.btn-danger` | Rose tinted, for destructive actions |

---

## Section Header Pattern

```jsx
// Correct
<div className="section-header">
  <p className="text-label">Gastos Fijos</p>
</div>

// Old pattern (replace when found)
<p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Gastos Fijos</p>
```

---

## Animations

| Class | Description |
|-------|-------------|
| `.anim-fade-up` | Fade in from below (list items) |
| `.anim-slide-up` | Slide up (modals, bottom sheets) |
| `.anim-scale-in` | Scale in (popovers, menus) |
| `.skeleton` | Shimmer loading placeholder |
| `.pulse-dot` | Pulsing notification dot |

---

## Bottom Navigation

Class: `.bottom-nav` — fixed bottom bar with blur + safe area support.

Active state: Uses a `bg-indigo-500/15` pill behind active icon (non-Add tabs). The Add button uses a dedicated raised square button.

---

## Responsive Layout

The app uses a mobile-first approach with `max-w-*` containers for desktop:

- Mobile (< 768px): Single column, full width
- Tablet (768px+): 2-column grid for cards, wider content
- Desktop (1024px+): 3-column grid possible, max-width container

### Tab container template:
```jsx
<div className="px-4 md:px-6 lg:px-8 pt-[calc(env(safe-area-inset-top)+16px)]
  pb-[calc(env(safe-area-inset-bottom)+90px)] max-w-2xl lg:max-w-3xl mx-auto space-y-4">
```

### 2-col card grid:
```jsx
<div className="grid grid-cols-2 md:grid-cols-2 gap-3">
```

---

## Amount Display

Use CSS utility classes for amounts:
```jsx
<p className="amount-gasto">-$15.000</p>    // Rose/red
<p className="amount-ingreso">+$50.000</p>  // Emerald/green
```

---

## Adding New Screens

1. Wrap content in: `<div className="px-4 md:px-6 lg:px-8 pt-[calc(env(safe-area-inset-top)+16px)] pb-[calc(env(safe-area-inset-bottom)+90px)] max-w-2xl mx-auto">`
2. Use section headers: `<div className="section-header"><p className="text-label">Título</p></div>`
3. Use card system: `mc-card`, `glass-card`, `glass-success`, etc.
4. Use button system: `btn-primary`, `btn-secondary`, `btn-ghost`
5. Amounts: always use `text-amount` or `text-display` with `amount-gasto`/`amount-ingreso`

---

## Breakpoints

| Name | Width | Tailwind prefix |
|------|-------|-----------------|
| Mobile | < 768px | (default) |
| Tablet | >= 768px | `md:` |
| Desktop | >= 1024px | `lg:` |
| Wide | >= 1280px | `xl:` |
