# 🎫 Ticket de mejora #001 — Sistema de Referral (crecimiento)

- **Para:** agentes iOS (Swift) + Android (Flutter) + Backend (Supabase)
- **Prioridad:** 🔴 Alta (es el motor de crecimiento orgánico del plan 30 días)
- **Origen:** Growth/Marketing — Plan Maestro 30 días, semana 2
- **Fecha:** 2026-05-30

---

## Contexto / hallazgo

Auditando el código encontré que la app **ya tiene invitaciones de hogar por token** (`household_invitations`, RPC `accept_household_invitation`, pantallas `InviteMemberView` iOS y `create_join_household_screen` Flutter). Eso permite **compartir un hogar**, que está perfecto.

**PERO eso NO es un sistema de referral de crecimiento.** Son cosas distintas:

| | Invitación de hogar (YA EXISTE) | Referral de crecimiento (FALTA) |
|---|---|---|
| Objetivo | Sumar a alguien A TU hogar | Traer un usuario NUEVO a la app |
| Resultado | Comparten el mismo saldo | Cada uno tiene su propia cuenta/hogar |
| Recompensa | — | Premium gratis / días / desbloqueos |
| Métrica | miembros por hogar | **K-factor / CAC orgánico** |

Muchos CTAs del plan de marketing dicen *"invitá a tu pareja/familia y ganá Premium"*. **Ese loop necesita el sistema de referral, que hoy no existe.**

---

## Qué pedimos construir

Un **programa de referidos** simple:

1. **Código/link único por usuario** (`hf.app/r/ABC123` o deep link). Generado al crear cuenta.
2. **Atribución**: cuando un usuario nuevo se registra con ese código, se registra quién lo invitó.
3. **Recompensa de doble lado** (el que más convierte):
   - Quien invita: +30 días de Premium por cada amigo que se registra y activa (ej. carga 1er gasto).
   - Quien es invitado: 14 días de Premium de bienvenida (en vez de 7).
4. **Pantalla "Invitá y ganá"**: muestra código, botón compartir nativo (share sheet con texto pre-armado por idioma), y contador de invitados/recompensas.
5. **Anti-abuso**: recompensa recién cuando el invitado **activa** (no solo se registra), límite de X referidos premiados/mes, validación server-side.

---

## Esquema sugerido (Supabase)

```sql
-- Tabla de referidos
create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references auth.users(id),
  referred_id uuid references auth.users(id),         -- null hasta que se registra
  code text not null,                                  -- el código del referrer
  status text not null default 'pending',              -- pending | signed_up | activated | rewarded
  reward_granted boolean not null default false,
  created_at timestamptz not null default now(),
  activated_at timestamptz
);
-- code único por usuario en profiles (o tabla aparte)
alter table public.profiles add column if not exists referral_code text unique;
```
- RLS: cada quien ve solo sus propios referrals. Recompensa otorgada **server-side** (Edge Function con service_role), nunca desde el cliente.
- Integrar con **RevenueCat** para conceder los días Premium (RevenueCat Promotional Entitlements / grant).
- Deep links: Universal Links (iOS) + App Links (Android) → `/r/:code`.

---

## Texto de compartir (pre-armado, por idioma)

**ES:**
```
Estoy usando Home Finance para ordenar la plata de casa 🏡 Te dejo mi link: tenés 14 días de Premium gratis 👉 [link]
```
**EN:**
```
I'm using Home Finance to keep my household money clear 🏡 Here's my link — you get 14 days of Premium free 👉 [link]
```
**PT:**
```
Tô usando o Home Finance pra organizar o dinheiro da casa 🏡 Meu link te dá 14 dias de Premium grátis 👉 [link]
```

---

## Definition of Done

- [ ] Migración Supabase + RLS + Edge Function de recompensa (server-side)
- [ ] Código único generado por usuario
- [ ] Deep link / Universal Link / App Link `/r/:code` resuelto en ambas apps
- [ ] Pantalla "Invitá y ganá" (iOS + Flutter) con share sheet localizado
- [ ] Atribución on signup + concesión de Premium vía RevenueCat al **activar**
- [ ] Anti-abuso básico
- [ ] Evento de analítica: `referral_sent`, `referral_signup`, `referral_activated`

> **Bloqueante de marketing:** hasta que esto exista, los CTAs de "invitá y ganá Premium" se reemplazan por "invitá a tu familia a tu hogar" (feature que sí existe). El referral con premio se promociona recién cuando esté liveado.
