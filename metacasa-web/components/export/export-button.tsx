"use client";

import * as React from "react";
import { Download, Loader2, type LucideIcon } from "lucide-react";
import { Button, type ButtonProps } from "@/components/ui/button";
import { useDownload } from "./use-download";

interface ExportButtonProps extends Omit<ButtonProps, "onClick"> {
  /** Ruta de exportación (ya con sus query params). */
  href: string;
  /** Texto del botón. */
  label: string;
  /** Texto mientras descarga (opcional). */
  pendingLabel?: string;
  /** Nombre de archivo de respaldo si el server no manda Content-Disposition. */
  fallbackName?: string;
  /** Ícono (por defecto Download). */
  icon?: LucideIcon;
}

/**
 * Botón de descarga de exportación. Dispara la descarga vía fetch→blob (estado
 * de carga + manejo de error con toast). Reutilizable en cualquier pantalla.
 */
export function ExportButton({
  href,
  label,
  pendingLabel,
  fallbackName,
  icon: Icon = Download,
  variant = "secondary",
  size = "sm",
  ...rest
}: ExportButtonProps) {
  const { pending, download } = useDownload();

  return (
    <Button
      type="button"
      variant={variant}
      size={size}
      disabled={pending}
      onClick={() => download(href, fallbackName)}
      {...rest}
    >
      {pending ? <Loader2 className="animate-spin" /> : <Icon />}
      {pending && pendingLabel ? pendingLabel : label}
    </Button>
  );
}
