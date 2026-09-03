import type { Metadata } from "next";
import Link from "next/link";
import { AcheFoodLogo } from "@/components/brand/achefood-logo";
import { PlansContent } from "@/components/commercial/plan-display";
import { getPlans } from "@/lib/commercial/plans";
import "@/components/brand/brand.css";
import "@/components/commercial/plans.css";

export const metadata: Metadata = { title: "Planos", description: "Compare os planos AcheFood para fornecedores. Experimente por 30 dias e escolha como continuar." };
export const dynamic = "force-dynamic";

export default async function PlansPage() {
  const plans = await getPlans();
  return <div className="commercial-page"><header className="commercial-header"><div className="container"><AcheFoodLogo /><nav aria-label="Navegação de planos"><Link href="/">Início</Link><Link href="/login">Entrar</Link></nav></div></header><main><PlansContent plans={plans} /></main><footer className="commercial-footer container"><AcheFoodLogo /><p>Quem procura, acha. Quem vende, conecta.</p><Link href="/privacidade">Privacidade</Link></footer></div>;
}
