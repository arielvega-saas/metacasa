import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

/**
 * Config de Vitest para la lógica pura de `lib/` (dinero, FX, salud financiera).
 * Entorno `node`: no testeamos componentes acá, así que no hace falta jsdom.
 * El alias `@/` espeja el `paths` de tsconfig.
 */
export default defineConfig({
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./", import.meta.url)),
      // `server-only` es un guard de build de Next (falla si el módulo entra a
      // un bundle de cliente) y no existe como paquete resoluble en Node. Sin
      // este alias, cualquier test que toque un módulo server-side —como el
      // dispatcher de tools del asistente— ni siquiera llega a importar.
      "server-only": fileURLToPath(new URL("./lib/__mocks__/server-only.ts", import.meta.url)),
    },
  },
  test: {
    environment: "node",
    include: ["lib/**/__tests__/**/*.test.ts"],
    // Con el pool por defecto el proceso queda colgado ~10 s tras terminar
    // ("something prevents Vite server from exiting"); con `forks` sale limpio.
    pool: "forks",
  },
});
