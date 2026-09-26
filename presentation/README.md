# SAWA — Presentation

| File | What |
|---|---|
| `SAWA_Presentation_AR.pptx` | The deck (20 slides, Arabic RTL, speaker notes, fade transitions, automatic entrance animations — no extra clicks) |
| `SAWA_Presentation_AR.pdf` | PDF export (same 20 slides) |
| `assets/screens/` | Real screenshots of the SAWA app (rendered from the app code) |
| `assets/phones/` | The same screens inside phone mockups |
| `assets/icons/`, `assets/bg/` | Icons (Font Awesome Free) and gradient backgrounds |
| `assets/photos/` | Story photos (free Unsplash/Pexels stock — see CREDITS.md) |
| `source/` | Scripts used to build the deck (pptxgenjs + mupdf, PowerPoint for PDF export) |

Notes
- Story photos (bride, students, company) are free stock images used for illustration — not SAWA customers.
- The provider dashboard screen uses an example account ("قاعة النخيل (مثال)"); the reference
  number on the success screen is an example.
- Numbers shown (23 source catalogs, 15 published providers, category counts) are real project data.
- Font: Segoe UI (ships with Windows). Presenting from macOS may substitute a similar font.

Rebuild: `node source/build_deck.js` then `source/apply_anim.ps1 -Pptx <pptx> -Pdf <pdf>` (needs PowerPoint on Windows).
