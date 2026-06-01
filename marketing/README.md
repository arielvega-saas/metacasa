# 🚀 Home Finance — Growth & Marketing Workspace

Centro de control de marketing de **Home Finance**. Todo lo que genera la "agencia" vive acá dentro del repo, versionado.

> **Agencia:** HomeFinance Growth Agency (interna)
> **Owner:** Ariel · **Arranque:** 2026-05-30

---

## 📊 Estado real de la app (esto manda la estrategia)

| Plataforma | Estado | ¿Se puede descargar hoy? | Acción de marketing |
|---|---|---|---|
| 🍎 **iOS** | **LIVE en App Store** (v1.0.x aprobada, v1.0.2 en review) | ✅ **SÍ** | **Empujar tráfico desde día 1** |
| 🤖 **Android** | **Prueba cerrada** (AAB subido, faltan declaraciones) | ❌ **NO** (solo 12 testers invitados) | Reclutar 12 testers → 14 días → producción → recién ahí, cañón |

**Implicancia clave:** todo link de descarga masivo en semanas 1–3 va a **iOS**. Android se promociona a lo grande **cuando pase a producción**. Mientras tanto, la ventana pre-Android sirve para **construir audiencia + reclutar los 12 testers** (que de todas formas necesitás).

---

## 🎨 Marca (one-pager)

- **Nombre:** `Home Finance`
- **Promesa:** *tranquilidad financiera para el hogar* (no una lista de features)
- **Taglines oficiales:**
  - 🇪🇸 *Tu plata más clara, tu casa más tranquila.* / *Tus finanzas del hogar, claras.*
  - 🇺🇸 *Calmer money. Calmer home.*
  - 🇧🇷 *Dinheiro mais claro, lar mais tranquilo.*
- **Diferenciadores (el "por qué nosotros"):**
  1. 👨‍👩‍👧 **Hecha para el hogar** — pareja/familia/roommates comparten un mismo saldo
  2. 🤖 **Asistente IA** que entiende tus números en lenguaje natural (foto de recibo, voz)
  3. 💱 **Multi-moneda** real (pesos+dólares / BRL+USD) — clave para LatAm e inmigrantes
  4. 🗣️ **Vocabulario local** (plata, sueldo, cuotas / boletos, salário, contas)
  5. 🔒 **Privacidad primero** + 🆓 **gratis para empezar** (Premium 7 días free)
- **Visual:** logo casa+flecha+barras en **verde sage glossy** sobre fondo **midnight verdoso** (design system "Midnight Sage").
- **Colores aprox.** (confirmar exactos en `metacasa-ios/MetaCasa/Core/DesignSystem.swift`):
  `#0F1411` midnight · `#2FBF71` sage/emerald glow · `#E8DCC0` champagne
- **Links oficiales:**
  - Privacidad: https://metacasa-app-cf592.web.app/privacy.html
  - Términos: https://metacasa-app-cf592.web.app/terms.html
  - Soporte: soporte@metacasa.app · support@metacasa.app · suporte@metacasa.app

---

## 👥 La "crew" (qué es real)

Cada rol es un **workstream** que ejecuto dentro del proyecto. Honestidad sobre capacidades:

| Rol | Qué hace de verdad | Límite real |
|---|---|---|
| **Agency Director** | Plan maestro, coordinación, prioridades | — |
| **Social Media Manager** | Handles, bios, banners, calendario, captions | No puedo *crear* las cuentas (verificación por teléfono/email la hacés vos) |
| **Content Creator ML** | Copy EN/ES/PT nativo + guiones de reel | Los videos finales los grabás vos o me pasás los assets |
| **Web & Landing** | Landing real en HTML + deploy (Firebase/Vercel) | "Carrd" no, pero hago algo mejor y propio |
| **Competitor Analyst** | Research real con búsqueda web + posicionamiento | Números = estimaciones públicas, siempre con fuente y fecha |
| **Community & Support** | Playbook + templates + reporte semanal | No corro un bot 24/7 *persistente*; respondo cuando me traés los mensajes |
| **Data & Improvement** | Tickets de mejora → agentes iOS/Android | — |
| **Visual Designer** | Specs + generación de imágenes con los assets reales | — |

---

## 🗂️ Índice del workspace

```
marketing/
├── README.md ······················ este archivo (control panel)
├── Plan/
│   └── plan-maestro-30-dias.md ····· ✅ plan día por día
├── Contenido/
│   ├── cuentas-bios-banners.md ····· ✅ handles + bios EN/ES/PT + specs
│   ├── semana-01-lanzamiento.md ···· ✅ primeros 7 posts × 3 idiomas (copy-paste)
│   ├── ES/ EN/ PT/ ················· (lotes de contenido por idioma)
├── Competidores/ ··················· ⏳ análisis YNAB/Monarch/etc (Paso 2)
├── ReportesMejoras/ ················ ⏳ tickets a iOS/Android + reportes semanales
├── Assets/
│   ├── Originales/ ················· ✅ 18 screenshots + 9 videos (EN/ES/PT) + INVENTARIO.md
│   └── Versionados/v1-2026-05/ ····· ✅ logo, icono, feature graphic, 6 screenshots ES
└── Landing/ ························· ⏳ landing page (Paso 3)
```

---

## ✅ Tracker de tareas

| # | Tarea | Estado |
|---|---|---|
| 1 | Estructura de carpetas + assets versionados | ✅ Hecho |
| 2 | Plan maestro 30 días | ✅ Hecho |
| 3 | Cuentas, bios y banners (EN/ES/PT) | ✅ Hecho (listo para que Ariel cree las cuentas) |
| 4 | Contenido semana 1 + 2 (3 idiomas) + calendario 30 días | ✅ Hecho (`Contenido/`, `Plan/calendario-publicacion.md`) |
| 4b | 9 reels listos (1080×1920, con audio) ES/EN/PT | ✅ `Contenido/reels/` |
| 4c | Ticket #002 freemium iOS + guía export emails | ✅ `ReportesMejoras/` |
| 5 | Análisis de competidores 2026 | ✅ Hecho (`Competidores/`, con fuentes web) |
| 6 | Landing **v3** (rediseño + sin precio, enfoque "probá 7 días Premium") + 18 videos + Supabase | ✅✅ **LIVE** en [metacasa-app-cf592.web.app/get/](https://metacasa-app-cf592.web.app/get/) |
| 7 | Playbook Community/Support + templates | ✅ Hecho (`ReportesMejoras/community-support-playbook.md`) |
| 8 | Primer ticket de mejora (referral system) | ✅ Hecho (`ReportesMejoras/ticket-001`) |

> **✅ Landing LIVE** en https://metacasa-app-cf592.web.app/get/ — form de email guardando en Supabase (`email_waitlist`), botón iOS al link real, swap ES/EN/PT.
>
> **Pendiente de Ariel (bloqueantes):**
> - ✅ ~~Pasar los videos/imágenes~~ — **HECHO 2026-05-30**: 18 screenshots + 9 videos importados y organizados en `Assets/Originales/{EN,ES,PT}/`. Ver `Assets/Originales/INVENTARIO.md`. Son piezas de marketing pro (teléfono 3D + glow + texto overlay por idioma).
> - Link real del App Store (iOS) para la landing y las bios — ⚠️ **no lo pude auto-detectar** (hay homónimos en la store, ver `Competidores/` "Alerta de colisión de marca"). Copialo de App Store Connect.
> - Decidir backend del form de email (Supabase / Formspree / mailto) — ver `Landing/README.md`
> - Crear las cuentas sociales (verificación por teléfono) — todo listo en `Contenido/cuentas-bios-banners.md`
> - **Re-login de Firebase** (`firebase login --reauthenticate`) — las credenciales expiraron; sin esto no se puede deployar la landing. Después: `bash marketing/Landing/deploy.sh`
