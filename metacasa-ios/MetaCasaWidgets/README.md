### Sprint 6 — MetaCasa i18n + XLSX + Widget/Live Activities scaffolds — 2026-04-21

**Fixes de i18n completos en vistas principales + nuevas capacidades**

- Pantalla de Settings, Apariencia, Notificaciones, Idioma completamente i18n (EN/ES/PT-BR).
- Backup + Assistant + Compare + Annual 100% i18n.
- XLSX import vía CoreXLSX SPM (0.14.2) añadido al target, `Core/Multimodal/XLSXImportService.swift` lo parsea on-device.
- Import inline en chat del asistente: XLS/XLSX/CSV → `TransactionCSVImporter.parse` → preview con counts → acción `Importar N` commit inline.
- Widget + Live Activities scaffold en `MetaCasaWidgets/` (archivos standalone, NO incluidos en target actual — requieren App Group setup en Apple Developer Portal).
- Streaming FoundationModels NO implementado (API actual de `respond(to:)` es suficiente por ahora; streaming queda post-launch).

**Deuda técnica remanente:**
- Legacy strings hardcoded aún en HelpCenterView (16 topics en ES) y LegalView (template legal en ES). Ambos son contenidos *grandes* que requieren traducción curada; i18n post-launch.
- `AddBillView` y `AddDebtView` usan bills.* / debts.* keys — confirmar cobertura en xcstrings.

