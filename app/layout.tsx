import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "AcheFood — Encontre fornecedores", template: "%s | AcheFood" },
  description: "Plataforma B2B que conecta empresas a fornecedores do setor alimentício.",
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"),
  openGraph: {
    title: "AcheFood — Encontre. Conecte. Faça negócios.",
    description: "Descubra fornecedores, solicite cotações e crie oportunidades B2B.",
    type: "website",
  },
  robots: { index: true, follow: true },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
