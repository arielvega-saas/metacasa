import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";

/**
 * robots.txt (Next auto-genera desde `app/robots.ts`). Solo la landing y el
 * login son indexables; toda la app autenticada, las APIs y los callbacks de
 * auth quedan fuera del crawl.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        allow: ["/", "/login"],
        disallow: [
          // Rutas de la app autenticada — app/(app)/*
          "/accounts",
          "/bills",
          "/budgets",
          "/categories",
          "/connect",
          "/dashboard",
          "/debts",
          "/goals",
          "/import",
          "/installments",
          "/profile",
          "/recurring",
          "/reports",
          "/templates",
          "/tools",
          "/transactions",
          // APIs y flujos internos
          "/api/",
          "/auth/",
          "/locked",
        ],
      },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
  };
}
