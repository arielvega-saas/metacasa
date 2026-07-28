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
