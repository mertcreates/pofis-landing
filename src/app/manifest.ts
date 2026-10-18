import type { MetadataRoute } from "next";
import { content } from "@/content";

export const dynamic = "force-static";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: content.brand.name,
    short_name: content.brand.name,
    description: content.meta.description,
    start_url: "/",
    display: "standalone",
    background_color: "#f7f8fa",
    theme_color: "#6554c0",
    icons: [
      {
        src: "/pofi-mark-256.webp",
        sizes: "256x256",
        type: "image/webp",
      },
    ],
  };
}
