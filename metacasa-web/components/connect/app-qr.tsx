import QRCode from "qrcode";
import { STORE_LINKS } from "@/components/app-links/store-links";

/**
 * QR REAL (no decorativo) que apunta a la App Store de Home Finance.
 * Se genera server-side como SVG inline (sin JS de runtime en el cliente,
 * sin peso extra de bundle). Escanear desde la compu → abre la ficha de la
 * app en el iPhone. Colores Midnight Sage: módulos oscuros sobre fondo claro
 * (mejor contraste para que cualquier cámara lo lea de forma confiable).
 */
export async function AppQr() {
  const svg = await QRCode.toString(STORE_LINKS.ios, {
    type: "svg",
    errorCorrectionLevel: "M",
    margin: 1,
    color: { dark: "#0e1312", light: "#f3f5f2" },
  });

  return (
    <div className="my-6 flex justify-center">
      <div
        className="hairline size-40 overflow-hidden rounded-[var(--radius-lg)] bg-[#f3f5f2] p-2"
        // El SVG ya viene sanitizado por la librería `qrcode` (no es input de usuario).
        dangerouslySetInnerHTML={{ __html: svg }}
        role="img"
        aria-label="Código QR para descargar Home Finance en la App Store"
      />
    </div>
  );
}
