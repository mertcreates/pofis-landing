import type { NextConfig } from "next";
import path from "node:path";

const config: NextConfig = {
  output: "export",
  images: { unoptimized: true },
  poweredByHeader: false,
  devIndicators: false,
  turbopack: {
    root: path.resolve(__dirname),
  },
};

export default config;

