import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "AcheFood — Encontrou. Conectou. Resolveu.", template: "%s | AcheFood" },
  description: "Plataforma B2B que conecta empresas a fornecedores do setor alimentício.",
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"),
  openGraph: {
    title: "AcheFood — Encontrou. Conectou. Resolveu.",
    description: "Descubra fornecedores, solicite cotações e crie oportunidades B2B.",
    type: "website",
    images: [{ url: "/brand/achefood-logo-oficial.jpeg", width: 1280, height: 461, alt: "AcheFood — Encontrou. Conectou. Resolveu." }],
  },
  twitter: {
    card: "summary_large_image",
    title: "AcheFood — Encontrou. Conectou. Resolveu.",
    description: "Descubra fornecedores, solicite cotações e crie oportunidades B2B.",
    images: ["/brand/achefood-logo-oficial.jpeg"],
  },
  icons: { icon: "/icon.png", apple: "/apple-icon.png" },
  robots: { index: true, follow: true },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
