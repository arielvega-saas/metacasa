import { describe, expect, it } from "vitest";
import {
  OFFLINE_PATH,
  isCacheablePage,
  isNeverCachePath,
  isSupabaseHost,
  shouldCachePage,
} from "@/lib/pwa/routes";

describe("isNeverCachePath", () => {
  it("bloquea /api/* (datos financieros crudos)", () => {
    for (const p of [
      "/api",
      "/api/export/transactions",
      "/api/import/parse",
      "/api/assistant",
    ]) {
      expect(isNeverCachePath(p)).toBe(true);
    }
  });

  it("bloquea /auth/* (callbacks y redirects de sesión)", () => {
    for (const p of ["/auth", "/auth/callback", "/auth/confirm", "/auth/handoff"]) {
      expect(isNeverCachePath(p)).toBe(true);
    }
  });

  it("no confunde rutas que sólo EMPIEZAN igual", () => {
    expect(isNeverCachePath("/apiario")).toBe(false);
    expect(isNeverCachePath("/authors")).toBe(false);
  });

  it("ignora querystring y barra final", () => {
    expect(isNeverCachePath("/api/export/report?ym=2026-07")).toBe(true);
    expect(isNeverCachePath("/auth/callback/")).toBe(true);
  });
});

describe("isCacheablePage", () => {
  it("permite las páginas públicas sin plata", () => {
    for (const p of [
      "/",
      "/login",
      "/register",
      "/forgot-password",
      "/reset-password",
      OFFLINE_PATH,
    ]) {
      expect(isCacheablePage(p)).toBe(true);
    }
  });

  it("NUNCA permite una ruta de la app (lleva saldos en el HTML)", () => {
    for (const p of [
      "/dashboard",
      "/transactions",
      "/accounts",
      "/budgets",
      "/reports",
      "/goals",
      "/debts",
      "/wallets",
      "/profile",
    ]) {
      expect(isCacheablePage(p)).toBe(false);
    }
  });

  it("no permite /api ni /auth aunque se pidan como navegación", () => {
    expect(isCacheablePage("/api/export/report")).toBe(false);
    expect(isCacheablePage("/auth/callback")).toBe(false);
  });

  it("tolera querystring y barra final", () => {
    expect(isCacheablePage("/login?returnTo=/dashboard")).toBe(true);
    expect(isCacheablePage("/login/")).toBe(true);
    expect(isCacheablePage("/dashboard?ym=2026-07")).toBe(false);
  });
});

describe("isSupabaseHost", () => {
  it("detecta el host del proyecto", () => {
    expect(isSupabaseHost("rgslvrxdppphzvqgcwbx.supabase.co")).toBe(true);
    expect(isSupabaseHost("RGSLVRXDPPPHZVQGCWBX.SUPABASE.CO")).toBe(true);
  });

  it("no matchea dominios ajenos que terminen parecido", () => {
    expect(isSupabaseHost("supabase.co.evil.com")).toBe(false);
    expect(isSupabaseHost("home-finance.app")).toBe(false);
  });
});

describe("shouldCachePage", () => {
  const ok = {
    pathname: "/login",
    status: 200,
    redirected: false,
    type: "basic",
  };

  it("guarda un 200 limpio de una página pública", () => {
    expect(shouldCachePage(ok)).toBe(true);
  });

  it("NO guarda una ruta con datos financieros", () => {
    expect(shouldCachePage({ ...ok, pathname: "/dashboard" })).toBe(false);
  });

  it("NO guarda un opaqueredirect (status 0): es el redirect al login", () => {
    expect(
      shouldCachePage({ ...ok, status: 0, type: "opaqueredirect" }),
    ).toBe(false);
  });

  it("NO guarda una respuesta que siguió un redirect", () => {
    expect(shouldCachePage({ ...ok, redirected: true })).toBe(false);
  });

  it("NO guarda errores ni 3xx", () => {
    for (const status of [204, 302, 307, 401, 404, 500]) {
      expect(shouldCachePage({ ...ok, status })).toBe(false);
    }
  });

  it("NO guarda respuestas que no sean de nuestro origen", () => {
    expect(shouldCachePage({ ...ok, type: "cors" })).toBe(false);
    expect(shouldCachePage({ ...ok, type: "opaque" })).toBe(false);
  });
});
