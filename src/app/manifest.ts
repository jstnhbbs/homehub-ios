import type { MetadataRoute } from "next";

const pngSizes = [48, 72, 96, 128, 144, 192, 384, 512] as const;

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Home Hub",
    short_name: "Home Hub",
    description: "Your family's shared calendar, routines, chores, and meals.",
    start_url: "/dashboard",
    display: "standalone",
    background_color: "#f7f3e9",
    theme_color: "#f7f3e9",
    orientation: "landscape",
    icons: [
      {
        src: "/icon.svg",
        sizes: "any",
        type: "image/svg+xml",
        purpose: "any",
      },
      ...pngSizes.map((size) => ({
        src: `/icons/icon-${size}.png`,
        sizes: `${size}x${size}`,
        type: "image/png" as const,
        purpose: "any" as const,
      })),
      {
        src: "/icons/icon-192.png",
        sizes: "192x192",
        type: "image/png",
        purpose: "maskable",
      },
      {
        src: "/icons/icon-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
  };
}
