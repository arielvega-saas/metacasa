# 🎫 Ticket de mejora #002 — Modelo de negocio: Trial-duro → Freemium

- **Para:** agentes iOS (Swift) + Android (Flutter) + Producto
- **Prioridad:** 🔴 Alta (afecta descargas, retención y la promesa del marketing)
- **Origen:** decisión de producto de Ariel + auditoría de código (2026-05-30)
- **Estado:** Propuesta — requiere decisión final de Ariel antes de ejecutar

---

## Contexto / hallazgo

Auditando el código encontré que **iOS hoy es trial-DURO**, no freemium. En `AccessController.swift` + `RootView.swift`:

> *"La app se descarga gratis. Al primer uso arranca un trial de 7 días. Pasados los 7 días, la app queda **completamente bloqueada** hasta que el usuario tenga una suscripción activa."*

O sea: a los 7 días aparece `LockedPaywallView` y **la app entera deja de funcionar** sin pagar.

**Eso NO es lo que Ariel quiere.** Su modelo deseado (sus palabras): *"que se la bajen, y el precio no sea algo que les impida bajar; una vez que usen la app podrán elegir dentro de la app"* → eso es **freemium** (gratis para siempre + Premium opcional).

Además: **Android (Flutter) hoy no tiene paywall** (gratis total). Así que iOS y Android se comportan distinto. Hay que unificar.

> **Estado actual de la landing:** ya está alineada al hard-trial real ("Probá 7 días Premium", sin prometer "gratis para siempre"). Si se hace este cambio a freemium, **la landing puede volver a hablar de "gratis para siempre"** (más fuerte para descargas).

---

## Decisión a tomar (Ariel)

| Modelo | Qué implica | Pro | Contra |
|---|---|---|---|
| **A) Freemium** (lo que querés) | Free para siempre + Premium desbloquea extras | Más descargas, mejor ASO, menos reseñas 1★ | Menor % de conversión inmediata |
| **B) Trial-duro** (lo que hace hoy) | 7 días y se bloquea | Más ingreso por usuario | Frena descargas, riesgo de reseñas malas y de rechazo de Apple (guideline 3.1) |

**Recomendación de growth:** **A (Freemium)** para la fase de lanzamiento. Con base de usuarios chica, lo que más importa es volumen de descargas + retención + reviews. La conversión se optimiza después con un buen paywall contextual.

---

## Qué construir (si se elige Freemium)

### iOS
1. **`AccessController.swift`** — cambiar el gate global:
   - HOY: `if subscribed || inTrial { .granted } else { .locked }`
   - NUEVO: la app **siempre** es `.granted`. Eliminar el estado `.locked` como muro global (o reservarlo solo para casos extremos, no para "trial vencido").
   - Mantener `isPremium` (= suscripción activa) como propiedad observable para gatear features puntuales.
   - El "trial de 7 días" pasa a ser un **trial de Premium** (durante 7 días el usuario tiene Premium completo; al vencer, baja a Free — NO se bloquea la app).
2. **`RootView.swift`** — quitar `LockedPaywallView` como gate. El `case .locked` desaparece del switch; siempre se muestra `mainApp`.
3. **Gating por feature** — donde hoy todo está detrás del muro, gatear SOLO lo premium. Definir la línea Free vs Premium (ver tabla abajo) y, en cada punto premium, mostrar un paywall contextual (`PaywallView`) en vez de bloquear.
4. **`PaywallView`** se mantiene, pero se invoca **contextualmente** (al tocar una feature premium) en vez de globalmente.

### Android (Flutter)
5. Implementar el **mismo modelo freemium** desde el inicio (hoy no hay paywall): RevenueCat + gating por feature idéntico a iOS. Usar el `AppGate` existente (loading/unauthenticated/noHousehold/ready) **sin** agregar un gate financiero global.

### Backend (Supabase) — sin cambios grandes
6. `user_entitlements` / `subscriptions` ya existen (escritos por webhook RevenueCat). Solo confirmar que el cliente lee `isPremium` desde ahí o desde StoreKit.

---

## Línea Free vs Premium sugerida (validar con Ariel)

| Capacidad | Free | Premium |
|---|---|---|
| Cargar ingresos/gastos | ✅ ilimitado | ✅ |
| Hogar compartido | ✅ (hasta 2 miembros) | ✅ ilimitado |
| Presupuesto por sobres | ✅ | ✅ |
| Multi-moneda | ✅ | ✅ |
| Asistente IA | ⏳ limitado (ej. 5 consultas/mes) | ✅ ilimitado |
| Modo voz | ❌ | ✅ |
| Reportes avanzados / proyecciones | ❌ | ✅ |
| Import XLSX / export CSV-PDF-JSON | ❌ | ✅ |
| Backup automático | ❌ | ✅ |

> Principio: lo **esencial siempre gratis** (que la app sea útil sola). Premium = potencia (IA ilimitada, voz, reportes, export, backup). Esto es lo que hace Monarch/YNAB-killers exitosos.

---

## Definition of Done

- [ ] Decisión de Ariel: Freemium (A) confirmado
- [ ] iOS: `AccessController` ya no bloquea la app al vencer trial; `isPremium` gatea features
- [ ] iOS: `RootView` sin `LockedPaywallView` global; paywall contextual
- [ ] Android: mismo modelo freemium (RevenueCat + gating por feature)
- [ ] Línea Free/Premium implementada y consistente iOS = Android
- [ ] Paywall contextual aparece al tocar feature premium (no al abrir la app)
- [ ] QA: usuario free al día 8 sigue usando la app (no se bloquea)
- [ ] Marketing: si se confirma, revertir landing a "gratis para empezar / gratis para siempre" + actualizar `APP_STORE_COPY.md`
- [ ] Apple: el cambio reduce riesgo con Guideline 3.1.1 (no forzar suscripción para funcionalidad básica)

> ⚠️ **Bloqueante de marketing:** mientras sea trial-duro, NO prometer "gratis para siempre" en ningún lado. Si pasa a freemium, recién ahí se puede.
