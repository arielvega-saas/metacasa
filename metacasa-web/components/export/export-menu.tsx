"use client";

import * as React from "react";
import {
  Download,
  Loader2,
  FileSpreadsheet,
  FileText,
  type LucideIcon,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import { useT } from "@/components/i18n/locale-provider";
import { useDownload } from "./use-download";

/** Una opción del menú de exportación (ej. PDF, Excel). */
export interface ExportOption {
  /** Clave estable para React. */
  key: string;
  /** Ruta de exportación con sus query params. */
  href: string;
  /** Texto de la opción. */
  label: string;
  /** Ícono (por defecto según formato si se omite). */
  icon?: LucideIcon;
  fallbackName?: string;
}

interface ExportMenuProps {
  /** Texto del botón disparador. */
  label?: string;
  /** Encabezado del menú (opcional). */
  menuLabel?: string;
  options: ExportOption[];
}

const ICON_BY_KEY: Record<string, LucideIcon> = {
  pdf: FileText,
  xlsx: FileSpreadsheet,
  excel: FileSpreadsheet,
};

/**
 * Menú desplegable de exportación: un disparador y varias opciones de formato
 * (PDF, Excel…). Cada opción dispara la descarga vía fetch→blob con estado de
 * carga compartido y manejo de error. Reutilizable.
 */
export function ExportMenu({ label, menuLabel, options }: ExportMenuProps) {
  const t = useT();
  const { pending, download } = useDownload();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button type="button" variant="secondary" size="sm" disabled={pending}>
          {pending ? <Loader2 className="animate-spin" /> : <Download />}
          {label ?? t("exportTools.actions.export")}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent>
        <DropdownMenuLabel>
          {menuLabel ?? t("exportTools.actions.menuLabel")}
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        {options.map((opt) => {
          const Icon = opt.icon ?? ICON_BY_KEY[opt.key] ?? Download;
          return (
            <DropdownMenuItem
              key={opt.key}
              // Evitamos que Radix cierre el foco antes de disparar la descarga.
              onSelect={(e) => {
                e.preventDefault();
                download(opt.href, opt.fallbackName);
              }}
            >
              <Icon /> {opt.label}
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
