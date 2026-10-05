import type { NextConfig } from "next";

// Sent with every response. Vercel already adds Strict-Transport-Security. There is no script-src
// on purpose: the theme script in the root layout is inline and Next injects its own, so a strict
// one would need per-request nonces for little gain on a site with no user-written HTML. The
// directives here are the ones that cost nothing: nobody can frame the site, point <base> at
// another origin, load plugins, or post a form somewhere else.
export const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "geolocation=(), microphone=(), payment=()" },
  {
    key: "Content-Security-Policy",
    value: "frame-ancestors 'none'; base-uri 'self'; object-src 'none'; form-action 'self'",
  },
];

const nextConfig: NextConfig = {
  allowedDevOrigins: ["127.0.0.1"],
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
  async redirects() {
    return [
      {
        source: "/naps",
        destination: "/sleep",
        permanent: true,
      },
      {
        source: "/snacks",
        destination: "/meals/snacks",
        permanent: true,
      },
      {
        source: "/recipes",
        destination: "/meals/recipes",
        permanent: true,
      },
      {
        source: "/recipes/:recipeId",
        destination: "/meals/recipes/:recipeId",
        permanent: true,
      },
    ];
  },
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "*.public.blob.vercel-storage.com",
        pathname: "/profiles/**",
      },
      {
        protocol: "https",
        hostname: "*.public.blob.vercel-storage.com",
        pathname: "/households/**",
      },
    ],
  },
  turbopack: {
    root: process.cwd(),
  },
};

export default nextConfig;
