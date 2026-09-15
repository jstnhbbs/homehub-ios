import type { MetadataRoute } from "next";

const pngSizes = [48, 72, 96, 128, 144, 192, 384, 512] as const;

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Beacon",
    short_name: "Beacon",
    description: "Your family's shared routines, chores, notes, calendar, and meals.",
    start_url: "/settings",
    display: "standalone",
    background_color: "#f7f3e9",
    theme_color: "#f7f3e9",
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
