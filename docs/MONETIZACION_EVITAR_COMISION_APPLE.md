# Monetización: cómo NO pagarle la comisión a Apple

> Documento explicativo. NO soy abogado y las políticas de Apple cambian y varían
> por país — verificá las App Store Review Guidelines vigentes (sección 3.1)
> antes de tomar decisiones. Esto es una guía práctica, no asesoría legal.

---

## 1. La regla de fondo (sin vueltas)

- **Si el usuario compra DENTRO de la app iOS → Apple cobra 15–30%. Siempre.**
  No hay forma legítima de usar el sistema de compra de Apple (IAP) y no pagar.
  Intentar evitarlo = suspensión de la app.
- **La ÚNICA forma legítima de no pagar la comisión = el usuario NO compra en la
  app. Compra en tu web (Stripe). La app solo LEE si está suscrito.**
  Es el modelo de Netflix, Spotify, Kindle: en el iPhone no te podés suscribir,
  solo usás lo que pagaste afuera.

### Los números (por qué importa)

| | Apple IAP | Stripe (web) |
|---|---|---|
| Comisión | 15–30% | ~2,9% + US$0,30 |
| Sobre US$10/mes | te quedan ~$7–8,50 | te quedan ~$9,40 |
| Sobre 100 subs × US$10 | perdés ~$150–300/mes | perdés ~$60/mes |

---

## 2. Cómo está TU app hoy

- **Web (`usehomefinance.com`):** gate de acceso **server-side** vía Supabase
  (`has_active_entitlement('premium')` + trial server-side). NO cobra IAP (es web).
  → La "fuente de verdad" de quién es Premium ya vive en TU base de datos.
- **App iOS (publicada):** tiene paywall **con IAP** (RevenueCat + StoreKit).
  El gate iOS es **local** (StoreKit `currentEntitlements`), no lee Supabase.
- **Sincronización de pago:** RevenueCat manda un webhook → tabla `subscriptions`
  → trigger → `user_entitlements`. (Hoy: 0 suscriptores reales.)

**Implicancia clave:** ya tenés media arquitectura para cobrar por web. Lo que
falta es el cobro Stripe en sí + decidir qué hace la app iOS.

---

## 3. Los 3 modelos posibles (de menor a mayor riesgo)

### Modelo A — "Silencioso / reader app"  ✅ RIESGO CERO, recomendado para empezar
- La app iOS **no ofrece comprar nada**: sin botón de suscripción, sin precios,
  sin link de pago. Solo: "Iniciá sesión" → si tu cuenta es Premium (porque
  pagaste en la web), tenés Premium; si no, ves la versión gratis.
- El usuario se suscribe **solo en la web** (`usehomefinance.com`) con Stripe.
- Apple **acepta esto sin problema** — es exactamente lo que hace Netflix.
- **Contra:** un usuario iOS que nunca visitó la web no sabe cómo pagar. Hay que
  guiarlo (ej: "gestioná tu plan desde usehomefinance.com" — SIN que sea un link
  de compra directo). Friction más alto, pero cero riesgo.

### Modelo B — "Web + mención permitida (steering)"  ⚠️ ZONA QUE MEJORÓ EN 2024
- Igual que A, pero la app **sí puede mencionar/linkear** el pago web.
- En 2024 Apple relajó la regla "anti-steering" (fallo Epic v. Apple en EE.UU. +
  DMA en Europa). Hoy se puede, PERO con formato exacto que Apple impone
  (pantalla de advertencia "vas a salir de la app", sin parecer un IAP, etc.),
  y **varía por país**.
- **Contra:** terreno sensible; mal implementado = rechazo o baja. Si se hace,
  hay que seguir al pie de la letra la guideline vigente.

### Modelo C — "Convivencia: IAP en iOS + Stripe en web"  💰 MÁS COMPLEJO
- iOS sigue cobrando con IAP (pagás 15–30% solo de esas ventas); web cobra Stripe
  (sin comisión). El usuario elige dónde paga; muchos elegirán iOS por comodidad.
- **Pro:** no perdés a nadie. **Contra:** seguís pagando comisión de los que pagan
  en iOS, y hay que unificar el estado (RevenueCat + Stripe → mismo entitlement).
  Es lo que muchas apps hacen en la práctica.

---

## 4. Recomendación para tu etapa

**Hoy: 0 suscriptores.** Construir todo Stripe ahora es preparar infraestructura
para ingresos que todavía no existen. Opciones sensatas:

1. **Pragmático:** dejá la app como está (IAP iOS) hasta tener tracción real. Si
   empezás a facturar fuerte y la comisión duele, ahí migrás a Modelo A/B y
   sumás Stripe web. Decisión basada en datos, no en miedo a la comisión.
2. **Preparar el terreno:** construir Stripe en la web AHORA (yo lo hago casi
   entero; vos creás cuenta Stripe + claves), dejándolo listo. La app iOS la
   dejás con IAP (Modelo C) o la pasás a silenciosa (Modelo A) en el próximo
   update. Así, el día que quieras empujar la web, ya está.

**Mi sugerencia honesta:** no es urgente. La comisión solo "duele" cuando hay
ventas. Priorizá conseguir usuarios primero; la optimización de la comisión es un
problema bueno de tener (significa que estás facturando).

---

## 5. Si decidís cobrar por web (Stripe) — qué hace falta

**Yo construyo (técnico):**
- Checkout de Stripe en `usehomefinance.com` (planes mensual/anual + trial).
- Webhook de Stripe → marca `user_entitlements` en Supabase (reusa el gate que ya existe).
- Página "gestionar suscripción" (portal de Stripe).
- Unificar: que web (Stripe) e iOS (RevenueCat) escriban el MISMO entitlement.

**Vos (no puedo, son secretos/pagos):**
- Crear cuenta en Stripe (gratis) + activar pagos (datos fiscales/bancarios).
- Pegar las claves de Stripe (igual que hicimos con Brevo).

**Decisión de producto tuya:**
- Qué modelo (A/B/C) para la app iOS.
- Precios web (pueden ser MÁS BARATOS que iOS justamente porque no pagás comisión
  — un gancho real para que paguen por web).

---

## 6. Aparte: usar Premium gratis vos mismo (dueño)

Distinto de la comisión. Para tu propio uso sin pagar:
- **Web:** se te puede insertar el entitlement Premium directo en Supabase. Listo.
- **iOS:** usá **offer codes** (App Store Connect → hasta 100 gratis/trimestre) o
  un sandbox/TestFlight tester. No te cobra.
