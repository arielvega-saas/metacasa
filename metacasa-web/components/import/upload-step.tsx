"use client";

import * as React from "react";
import { FileUp, FileSpreadsheet, Loader2, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { useT } from "@/components/i18n/locale-provider";
import type { ParseResponse } from "./types";

const ACCEPT = ".xlsx,.csv";
const MAX_BYTES = 5 * 1024 * 1024;

interface Props {
  onParsed: (data: ParseResponse, fileName: string) => void;
}

/** Paso 1: subir el archivo (drag & drop o file picker) → /api/import/parse. */
export function UploadStep({ onParsed }: Props) {
  const t = useT();
  const inputRef = React.useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = React.useState(false);
  const [uploading, setUploading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [fileName, setFileName] = React.useState<string | null>(null);

  /** Mapea el código de error del backend a un mensaje localizado. */
  const errorMessage = React.useCallback(
    (code: string) => {
      switch (code) {
        case "fileTooLargeError":
        case "fileTypeError":
        case "emptyFileError":
        case "parseError":
          return t(`importTools.${code}`);
        default:
          return t("importTools.parseError");
      }
    },
    [t],
  );

  const handleFile = React.useCallback(
    async (file: File) => {
      setError(null);
      const name = file.name.toLowerCase();
      // Validación cliente (el backend revalida igual).
      if (!name.endsWith(".xlsx") && !name.endsWith(".csv")) {
        setError(t("importTools.fileTypeError"));
        return;
      }
      if (file.size > MAX_BYTES) {
        setError(t("importTools.fileTooLargeError"));
        return;
      }

      setFileName(file.name);
      setUploading(true);
      try {
        const form = new FormData();
        form.append("file", file);
        const res = await fetch("/api/import/parse", {
          method: "POST",
          body: form,
        });
        const data = await res.json().catch(() => null);
        if (!res.ok || !data) {
          setError(errorMessage(data?.error ?? "parseError"));
          setFileName(null);
          return;
        }
        onParsed(data as ParseResponse, file.name);
      } catch {
        setError(t("importTools.parseError"));
        setFileName(null);
      } finally {
        setUploading(false);
      }
    },
    [errorMessage, onParsed, t],
  );

  return (
    <div className="space-y-4">
      <div
        role="button"
        tabIndex={0}
        aria-disabled={uploading}
        onClick={() => !uploading && inputRef.current?.click()}
        onKeyDown={(e) => {
          if ((e.key === "Enter" || e.key === " ") && !uploading) {
            e.preventDefault();
            inputRef.current?.click();
          }
        }}
        onDragOver={(e) => {
          e.preventDefault();
          if (!uploading) setDragging(true);
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragging(false);
          if (uploading) return;
          const f = e.dataTransfer.files?.[0];
          if (f) void handleFile(f);
        }}
        className={cn(
          "hairline flex cursor-pointer flex-col items-center justify-center rounded-[var(--radius-xl)] px-6 py-12 text-center transition-colors",
          dragging ? "border-primary/50 bg-primary/5" : "bg-inset hover:bg-white/[0.03]",
          uploading && "pointer-events-none opacity-70",
        )}
      >
        <span className="bg-primary/15 text-primary mb-4 flex size-12 items-center justify-center rounded-[var(--radius-lg)]">
          {uploading ? (
            <Loader2 className="size-6 animate-spin" />
          ) : (
            <FileUp className="size-6" />
          )}
        </span>
        <p className="text-sm font-semibold text-foreground">
          {uploading ? t("importTools.uploading") : t("importTools.uploadTitle")}
        </p>
        {!uploading && (
          <>
            <p className="text-text-muted mt-1 text-sm">{t("importTools.uploadHint")}</p>
            <p className="text-text-dim mt-3 text-xs">{t("importTools.uploadFormats")}</p>
            <Button type="button" variant="secondary" className="mt-5" tabIndex={-1}>
              <FileSpreadsheet className="size-4" />
              {t("importTools.uploadButton")}
            </Button>
          </>
        )}
        {uploading && fileName && (
          <p className="text-text-dim mt-2 max-w-full truncate text-xs">{fileName}</p>
        )}

        <input
          ref={inputRef}
          type="file"
          accept={ACCEPT}
          className="sr-only"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) void handleFile(f);
            // Permitir re-subir el mismo archivo.
            e.target.value = "";
          }}
        />
      </div>

      {error && (
        <div className="bg-expense/10 text-expense flex items-start gap-2 rounded-[var(--radius-md)] px-4 py-3 text-sm">
          <X className="mt-0.5 size-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}
    </div>
  );
}
