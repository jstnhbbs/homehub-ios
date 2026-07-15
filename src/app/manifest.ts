import type { MetadataRoute } from "next";

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
    ],
  };
}
