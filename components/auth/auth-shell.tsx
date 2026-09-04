"use client";

import { AcheFoodLogo } from "@/components/brand/achefood-logo";
import { Handshake, MapPin, Search, Users } from "lucide-react";
import { useRef } from "react";
import { usePageMotion } from "@/lib/motion/use-page-motion";

export function AuthShell({ children }: { children: React.ReactNode }) {
  const motionScope = useRef<HTMLElement>(null);
  usePageMotion(motionScope, "login");
  return (
    <main className="auth-page" ref={motionScope}>
      <section className="auth-brand-panel">
        <div className="auth-brand-header">
          <AcheFoodLogo />
        </div>

        <div className="auth-brand-copy">
          <h1>
            Encontre.<br />
            Conecte.<br />
            Faça <span>negócios.</span>
          </h1>
          <div className="orange-line" />
          <p>
            O AcheFood conecta compradores e fornecedores em um único ambiente <b>B2B.</b>
          </p>
        </div>

        <div className="auth-network" aria-hidden="true">
          <div className="network-ring">
            <span className="map-core"><MapPin /></span>
            <i className="network-node n1"><Search /></i>
            <i className="network-node n2"><Users /></i>
            <i className="network-node n3"><Handshake /></i>
            <div className="float-card f1"><b>🧀 Queijo Mussarela</b><small>Laticínios Bom Sabor · PR</small></div>
            <div className="float-card f2"><b>🏪 Distribuidora Exemplo</b><small>Fornecedor verificado</small></div>
            <div className="float-card f3"><b>🥬 Produtos Frescos</b><small>Diversas categorias</small></div>
          </div>
        </div>

        <blockquote>
          Quem procura, <b>acha.</b><br />
          Quem vende, <b>conecta.</b>
        </blockquote>
      </section>

      <section className="auth-form-panel">
        {children}
        <div className="auth-legal">
          <a href="/termos">Termos de Uso</a>
          <span>•</span>
          <a href="/privacidade">Política de Privacidade</a>
        </div>
      </section>
    </main>
  );
}
