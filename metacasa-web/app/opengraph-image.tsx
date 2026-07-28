import { ImageResponse } from "next/og";

/**
 * Imagen Open Graph generada en runtime con `next/og` — cero assets externos.
 * Marca "Home Finance" sobre el fondo Midnight Sage (#0E1312), texto crema
 * (#F2EFE7) y acento sage (#B8D4C2). Aplica a todas las rutas (vive en la
 * raíz de `app/`).
 */

export const alt = "Home Finance — Las finanzas de tu hogar, claras.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpengraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "flex-start",
          padding: "96px",
          backgroundColor: "#0E1312",
          backgroundImage:
            "radial-gradient(circle at 18% 0%, rgba(184,212,194,0.12), rgba(184,212,194,0) 55%)",
        }}
      >
        {/* Marca chica arriba: punto sage + wordmark en mayúsculas. */}
        <div style={{ display: "flex", alignItems: "center" }}>
          <div
            style={{
              width: 14,
              height: 14,
              borderRadius: 7,
              backgroundColor: "#B8D4C2",
              marginRight: 14,
            }}
          />
          <div
            style={{
              fontSize: 26,
              letterSpacing: 8,
              color: "#B8D4C2",
              textTransform: "uppercase",
            }}
          >
            Home Finance
          </div>
        </div>

        {/* Nombre grande en crema. */}
        <div
          style={{
            marginTop: 36,
            fontSize: 104,
            fontWeight: 700,
            lineHeight: 1.05,
            color: "#F2EFE7",
          }}
        >
          Home Finance
        </div>

        {/* Barra de acento sage. */}
        <div
          style={{
            marginTop: 32,
            width: 96,
            height: 8,
            borderRadius: 4,
            backgroundColor: "#B8D4C2",
          }}
        />

        {/* Tagline en crema. */}
        <div
          style={{
            marginTop: 32,
            fontSize: 42,
            color: "#F2EFE7",
            opacity: 0.85,
          }}
        >
          Las finanzas de tu hogar, claras.
        </div>
      </div>
    ),
    { ...size },
  );
}
