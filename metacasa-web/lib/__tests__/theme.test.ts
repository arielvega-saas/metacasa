import { describe, expect, it } from "vitest";
import {
  DEFAULT_THEME,
  THEMES,
  isTheme,
  resolveTheme,
  themeClass,
  themeInitScript,
} from "@/lib/theme";

describe("isTheme", () => {
  it("acepta los tres estados válidos", () => {
    for (const t of THEMES) expect(isTheme(t)).toBe(true);
  });

  it("rechaza basura y valores vacíos", () => {
    for (const v of ["", "Dark", "auto", "<script>", undefined, null]) {
      expect(isTheme(v)).toBe(false);
    }
  });
});

describe("themeClass", () => {
  it("mapea la preferencia a la clase de <html>", () => {
    expect(themeClass("light")).toBe("light");
    expect(themeClass("dark")).toBe("dark");
  });

  it("deja `system` sin clase: la resuelve el script inline", () => {
    expect(themeClass("system")).toBe("");
  });

  it("el default es `system`", () => {
    expect(DEFAULT_THEME).toBe("system");
  });
});

describe("resolveTheme", () => {
  it("respeta la elección explícita, ignore el SO", () => {
    expect(resolveTheme("light", true)).toBe("light");
    expect(resolveTheme("dark", false)).toBe("dark");
  });

  it("sigue al SO cuando es `system`", () => {
    expect(resolveTheme("system", true)).toBe("dark");
    expect(resolveTheme("system", false)).toBe("light");
  });
});

describe("themeInitScript", () => {
  it("serializa la preferencia como literal JSON (sin romper el script)", () => {
    expect(themeInitScript("dark")).toContain('var p="dark"');
    expect(themeInitScript("system")).toContain('var p="system"');
  });

  it("aplica y quita ambas clases (nunca deja `light` y `dark` juntas)", () => {
    const src = themeInitScript("light");
    expect(src).toContain('classList.toggle("dark"');
    expect(src).toContain('classList.toggle("light"');
  });

  it("sólo escucha cambios del SO cuando la preferencia es `system`", () => {
    expect(themeInitScript("system")).toContain('if(p==="system")');
  });

  it("no rompe si matchMedia falla (va envuelto en try/catch)", () => {
    expect(themeInitScript("system")).toContain("try{");
    expect(themeInitScript("system")).toContain("catch(e){}");
  });

  it("no interpola nada fuera de los tres estados conocidos", () => {
    // El único punto de interpolación es `p`, y siempre viene de isTheme().
    for (const t of THEMES) {
      const src = themeInitScript(t);
      expect(src.match(/"/g)?.length).toBe(themeInitScript("dark").match(/"/g)?.length);
      expect(src).not.toContain("</script");
    }
  });
});
