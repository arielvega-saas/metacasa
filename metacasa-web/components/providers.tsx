"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { Toaster } from "sonner";

/**
 * Providers globales del cliente:
 * - TanStack Query para caché/optimistic updates sobre Supabase.
 * - Sonner para toasts on-brand.
 */
export function Providers({ children }: { children: React.ReactNode }) {
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
        theme="dark"
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
