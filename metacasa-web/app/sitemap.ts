import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";

/**
 * sitemap.xml (Next auto-genera desde `app/sitemap.ts`). Solo las URLs
 * públicas: la landing y el login. El resto vive detrás de auth y está
 * excluido en `app/robots.ts`.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: SITE_URL,
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 1,
    },
    {
      url: `${SITE_URL}/login`,
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 0.5,
    },
  ];
}
