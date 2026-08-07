/**
 * Stub de `server-only` para los tests.
 *
 * En Next, `import "server-only"` es un guard: si el módulo termina en un bundle
 * de cliente, el build falla. En Node no resuelve a nada, así que sin este stub
 * los tests de cualquier módulo server-side revientan al importar.
 *
 * Vacío a propósito — el guard es cosa del build, no de runtime.
 */
export {};
