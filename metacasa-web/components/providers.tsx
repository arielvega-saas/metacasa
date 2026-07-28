"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { Toaster } from "sonner";
import { DEFAULT_THEME, type Theme } from "@/lib/theme";

/**
 * Providers globales del cliente:
 * - TanStack Query para caché/optimistic updates sobre Supabase.
 * - Sonner para toasts on-brand (sigue el tema: sonner entiende
 *   "system" | "light" | "dark", los mismos tres estados que la cookie).
 */
export function Providers({
  children,
  theme = DEFAULT_THEME,
}: {
  children: React.ReactNode;
  theme?: Theme;
}) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 30_000,
            refetchOnWindowFocus: false,
            retry: 1,
          },
        },
      }),
  );

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <Toaster
        theme={theme}
        position="top-center"
        richColors
        toastOptions={{
          style: {
            background: "var(--mc-surface-2)",
            border: "1px solid var(--mc-hairline)",
            color: "var(--mc-text)",
          },
        }}
      />
    </QueryClientProvider>
  );
}
