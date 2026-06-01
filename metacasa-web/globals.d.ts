// Permite imports de CSS como side-effect bajo `tsc --noEmit`.
// (next build maneja el CSS vía su propio pipeline; esto es solo para el typecheck.)
declare module "*.css";
