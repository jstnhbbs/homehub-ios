import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  allowedDevOrigins: ["127.0.0.1"],
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
