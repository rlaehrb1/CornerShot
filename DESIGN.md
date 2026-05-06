---
version: alpha
name: CornerShot Calm Utility
description: A quiet, approachable macOS utility interface for assigning hot-corner actions and reviewing clipboard history.
colors:
  primary: "#1F2933"
  secondary: "#59636F"
  accent: "#2563EB"
  success: "#047857"
  warning: "#C2410C"
  danger: "#DC2626"
  background: "#F5F7FA"
  surface: "#FFFFFF"
  surface-muted: "#EEF2F7"
  border: "#D7DEE8"
typography:
  title:
    fontFamily: SF Pro
    fontSize: 22px
    fontWeight: 700
    lineHeight: 1.2
  section-title:
    fontFamily: SF Pro
    fontSize: 13px
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: SF Pro
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.45
  caption:
    fontFamily: SF Pro
    fontSize: 11px
    fontWeight: 400
    lineHeight: 1.3
rounded:
  sm: 6px
  md: 10px
  lg: 14px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
components:
  utility-window:
    backgroundColor: "{colors.background}"
    textColor: "{colors.primary}"
  utility-panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: 14px
  quiet-button:
    backgroundColor: "{colors.surface-muted}"
    textColor: "{colors.primary}"
    rounded: "{rounded.sm}"
  status-badge:
    backgroundColor: "{colors.surface-muted}"
    textColor: "{colors.primary}"
    rounded: "{rounded.sm}"
  ocr-badge:
    backgroundColor: "{colors.accent}"
    textColor: "#FFFFFF"
    rounded: "{rounded.sm}"
  available-badge:
    backgroundColor: "{colors.success}"
    textColor: "#FFFFFF"
    rounded: "{rounded.sm}"
  modifier-badge:
    backgroundColor: "{colors.warning}"
    textColor: "#FFFFFF"
    rounded: "{rounded.sm}"
  conflict-badge:
    backgroundColor: "{colors.danger}"
    textColor: "#FFFFFF"
    rounded: "{rounded.sm}"
  divider:
    backgroundColor: "{colors.border}"
    textColor: "{colors.secondary}"
---

## Overview

CornerShot should feel like a small native macOS utility: calm, readable, and quick to understand. The UI should prioritize clear labels, compact spacing, and predictable controls over decorative styling.

## Colors

Use system-adaptive macOS surfaces in the app, with this palette as the semantic guide. Blue is reserved for the selected/accent state and OCR-ready signals. Red is used only for real macOS hot-corner conflicts. Orange communicates modifier-key caution without feeling like an error.

## Typography

Use SF Pro through AppKit system fonts. Titles should be confident but not oversized. Utility rows, captions, and status text should stay compact and scan-friendly.

## Layout

Keep settings and history windows dense enough for repeated use. Use 8px rhythm, 16-24px outer margins, and grouped controls that align cleanly. Avoid landing-page composition, oversized hero text, and ornamental backgrounds.

## Shapes

Use 6-14px corner radius. Interactive rows and panels should feel soft but still native to macOS, with quiet borders and restrained hover states.

## Components

Hot-corner panels should read as four equal controls around a simple screen preview. Clipboard rows should show one strong primary line, one muted metadata line, and small icon controls. Screenshot previews should be lightweight and glanceable.

## Do's and Don'ts

- Do: keep labels short and useful.
- Do: use system colors where possible so dark mode remains natural.
- Do: reserve strong color for status and action feedback.
- Don't: add marketing-style hero sections, large decorative cards, gradients, or busy illustration.
- Don't: let repeated utility controls compete with the actual selected action.
