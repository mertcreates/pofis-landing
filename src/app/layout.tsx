import type { Metadata, Viewport } from "next";
import Script from "next/script";
import { GeistSans } from "geist/font/sans";
import { GeistMono } from "geist/font/mono";
import { content } from "@/content";
import "./globals.css";

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f7f8fa" },
    { media: "(prefers-color-scheme: dark)", color: "#17151d" },
  ],
};

export const metadata: Metadata = {
  metadataBase: new URL(content.meta.url),
  title: {
    default: content.meta.title,
    template: `%s · ${content.brand.name}`,
  },
  description: content.meta.description,
  applicationName: content.brand.name,
  keywords: [...content.meta.keywords],
  authors: [{ name: content.footer.creditLabel, url: content.footer.creditUrl }],
  creator: content.footer.creditLabel,
  publisher: content.brand.name,
  formatDetection: {
    telephone: false,
    email: false,
    address: false,
  },
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: content.meta.title,
    description: content.meta.description,
    url: "/",
    siteName: content.brand.name,
    locale: content.meta.locale,
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: content.meta.title,
    description: content.meta.description,
  },
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/pofi-mark-256.webp", type: "image/webp" },
    ],
    apple: [
      { url: "/pofi-mark-256.webp", type: "image/webp" },
    ],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
};

const themeInitScript = `
  (() => {
    try {
      const saved = localStorage.getItem('pofis:theme:v1');
      if (saved === 'light' || saved === 'dark') {
        document.documentElement.dataset.theme = saved;
      }
    } catch {}
  })();
`;

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="tr"
      className={`${GeistSans.variable} ${GeistMono.variable}`}
      suppressHydrationWarning
    >
      <head>
        <script
          id="theme-init"
          dangerouslySetInnerHTML={{ __html: themeInitScript }}
        />
      </head>
      <body>
        <div className="page-wrapper">{children}</div>
        <Script
          src="https://www.googletagmanager.com/gtag/js?id=G-3YJTX7B799"
          strategy="afterInteractive"
        />
        <Script id="google-analytics" strategy="afterInteractive">
          {`
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', 'G-3YJTX7B799');
          `}
        </Script>
      </body>
    </html>
  );
}
