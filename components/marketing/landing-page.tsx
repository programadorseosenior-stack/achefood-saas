"use client";

import Link from "next/link";
import { ArrowRight, Building2, Check, ChevronDown, Handshake, MapPin, Menu, PackageSearch, Search, ShieldCheck, Store, Target, Users } from "lucide-react";
import { useMemo, useRef, useState } from "react";
import { AcheFoodLogo } from "@/components/brand/achefood-logo";
import { HomePlans } from "@/components/commercial/plan-display";
import type { Plan } from "@/lib/commercial/types";
import { usePageMotion } from "@/lib/motion/use-page-motion";

const suppliers = [
  ["Laticínios Bom Sabor", "Maringá - PR", "🥛", "Entrega para todo Brasil"],
  ["Distribuidora Exemplo", "Campinas - SP", "🧀", "Entrega em SP e região"],
  ["Casa do Queijo", "Jundiaí - SP", "🏪", "Entrega em SP e região"],
  ["Requinte Laticínios", "Curitiba - PR", "🧈", "Entrega para Sul do Brasil"],
];

export function LandingPage({ plans }: { plans: Plan[] }) {
  const motionScope = useRef<HTMLDivElement>(null);
  usePageMotion(motionScope, "home");
  const [menuOpen, setMenuOpen] = useState(false);
  const [term, setTerm] = useState("");
  const filtered = useMemo(
    () => suppliers.filter((supplier) => `${supplier[0]} ${supplier[1]}`.toLowerCase().includes(term.toLowerCase())),
    [term],
  );

  return (
    <div className="landing" ref={motionScope}>
      <header className="marketing-header">
        <div className="container header-inner">
          <AcheFoodLogo />
          <button className="menu-toggle" aria-label="Abrir menu" onClick={() => setMenuOpen((v) => !v)}><Menu /></button>

          <nav className={menuOpen ? "open" : ""} aria-label="Navegação principal">
            <a href="#como-funciona">Como funciona</a>
            <a href="#publicos">Compradores</a>
            <a href="#publicos">Fornecedores</a>
            <a href="#planos">Planos</a>
            <a href="#sobre">Sobre</a>
            <Link href="/login" className="mobile-login">Entrar</Link>
            <Link href="/cadastro" className="af-btn af-btn-primary mobile-login">Criar conta grátis</Link>
          </nav>

          <div className="header-actions">
            <Link href="/login">Entrar</Link>
            <Link href="/cadastro" className="af-btn af-btn-primary">Criar conta grátis</Link>
          </div>
        </div>
      </header>

      <main>
        <section className="hero container">
          <div className="hero-copy">
            <span className="eyebrow">Plataforma B2B para o setor alimentício</span>
            <h1>
              Encontre <span>fornecedores.</span><br />
              Crie <span>oportunidades.</span><br />
              Faça <span>negócios.</span>
            </h1>
            <p>O AcheFood conecta empresas que procuram produtos aos fornecedores certos.</p>

            <div className="hero-actions">
              <Link className="af-btn af-btn-primary" href="/cadastro">Começar gratuitamente <ArrowRight size={18} /></Link>
              <Link className="af-btn af-btn-secondary" href="/cadastro?tipo=fornecedor">Sou fornecedor</Link>
            </div>

            <div className="trust-row">
              <span><Check /> Conexões qualificadas</span>
              <span><ShieldCheck /> Ambiente seguro</span>
              <span><Handshake /> Mais negócios</span>
            </div>
          </div>

          <div className="product-preview" aria-label="Prévia do aplicativo AcheFood">
            <div className="preview-sidebar"><span>AF</span><i /><i /><i /><i /></div>
            <div className="preview-content">
              <div className="preview-search"><Search size={14} /> Ex.: Mussarela, Bacon, Arroz...</div>
              <b>Buscar produtos</b>
              <div className="mini-categories">
                <span>🥛<small>Laticínios</small></span>
                <span>🥩<small>Carnes</small></span>
                <span>🥤<small>Bebidas</small></span>
                <span>🥬<small>Hortifruti</small></span>
              </div>
              <b>Fornecedores em destaque</b>
              <div className="mini-suppliers">
                {suppliers.slice(0, 3).map((supplier) => (
                  <span key={supplier[0]}>
                    <i>{supplier[2]}</i>
                    <b>{supplier[0]}</b>
                    <small>{supplier[1]}</small>
                  </span>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section id="como-funciona" className="how section-pad">
          <div className="container">
            <h2 className="section-title">Encontrar o fornecedor certo<br />ficou <span>mais simples.</span></h2>
            <div className="steps">
              {[
                [Search, "Buscar", "Encontre produtos ou serviços que sua empresa precisa."],
                [MapPin, "Encontrar", "Veja fornecedores qualificados perto de você."],
                [PackageSearch, "Solicitar", "Envie solicitações de cotação de forma rápida."],
                [Handshake, "Conectar", "Negocie e feche negócios com segurança."],
              ].map(([Icon, title, text], index) => {
                const C = Icon as typeof Search;
                return (
                  <article key={String(title)}>
                    <div className="step-icon"><C /></div>
                    <em>0{index + 1}</em>
                    <h3>{String(title)}</h3>
                    <p>{String(text)}</p>
                  </article>
                );
              })}
            </div>
          </div>
        </section>

        <section id="publicos" className="audience section-pad">
          <div className="container">
            <h2 className="section-title">Feito para <span>quem compra</span><br />e para <span>quem fornece.</span></h2>
            <div className="audience-grid">
              <article className="af-card">
                <div className="audience-icon orange"><PackageSearch /></div>
                <small>COMPRADORES</small>
                <h3>Encontre produtos<br />e fornecedores.</h3>
                <ul>
                  <li>Busque produtos de forma rápida</li>
                  <li>Receba cotações de vários fornecedores</li>
                  <li>Compare e escolha a melhor opção</li>
                </ul>
                <Link href="/cadastro?tipo=comprador" className="af-btn af-btn-primary">Quero comprar</Link>
              </article>

              <article className="af-card">
                <div className="audience-icon navy"><Store /></div>
                <small>FORNECEDORES</small>
                <h3>Transforme procura<br />em oportunidade.</h3>
                <ul>
                  <li>Seja encontrado por quem procura</li>
                  <li>Receba solicitações de cotação</li>
                  <li>Destaque seus produtos e serviços</li>
                </ul>
                <Link href="/cadastro?tipo=fornecedor" className="af-btn af-btn-secondary">Quero fornecer</Link>
              </article>
            </div>
          </div>
        </section>

        <section className="supplier-search section-pad">
          <div className="container">
            <h2 className="section-title">O que sua empresa está <span>procurando?</span></h2>
            <div className="search-shell">
              <label>
                <Search size={18} />
                <input value={term} onChange={(e) => setTerm(e.target.value)} placeholder="Ex.: Mussarela, Bacon, Arroz..." />
              </label>
              <button type="button">Produto <ChevronDown /></button>
              <button type="button">Categoria <ChevronDown /></button>
              <button type="button" className="af-btn af-btn-primary">Buscar</button>
            </div>

            <div className="supplier-grid">
              {filtered.map((supplier, index) => (
                <article className="supplier-card af-card" key={supplier[0]}>
                  <div className="supplier-photo">{supplier[2]}</div>
                  <h3>{supplier[0]}</h3>
                  <p><MapPin /> {supplier[1]} · {(2.3 + index * 1.4).toFixed(1)} km</p>
                  <p className="verified"><ShieldCheck /> Fornecedor verificado</p>
                  <small>{supplier[3]}</small>
                  <Link href="/login">Ver perfil</Link>
                </article>
              ))}
            </div>

            {filtered.length === 0 && (
              <div className="empty-search">Nenhum fornecedor encontrado. <Link href="/cadastro">O AcheFood procura para você.</Link></div>
            )}
          </div>
        </section>

        <section className="wanted section-pad">
          <div className="container">
            <h2 className="section-title">Não encontrou? O AcheFood<br /><span>procura para você.</span></h2>
            <div className="steps wanted-steps">
              {[
                [PackageSearch, "Crie sua demanda", "Conte o que precisa e onde está procurando."],
                [Search, "Nossa equipe busca", "Procuramos fornecedores ideais para você."],
                [Target, "Receba oportunidades", "Você recebe as melhores opções."],
                [Handshake, "Conecte-se e negocie", "Escolha e feche negócios com segurança."],
              ].map(([Icon, title, description]) => {
                const C = Icon as typeof Search;
                return (
                  <article key={String(title)}>
                    <div className="step-icon"><C /></div>
                    <h3>{String(title)}</h3>
                    <p>{String(description)}</p>
                  </article>
                );
              })}
            </div>
          </div>
        </section>

        <section className="dashboard-demo section-pad">
          <div className="container">
            <h2 className="section-title">Acompanhe tudo <span>em um só lugar.</span></h2>
            <div className="demo-board af-card">
              <div className="demo-kpis">
                {[[PackageSearch, "Produtos visualizados"], [Users, "Fornecedores"], [Target, "Cotações"], [Handshake, "Conexões"]].map(([Icon, label]) => {
                  const C = Icon as typeof Search;
                  return (
                    <span key={String(label)}>
                      <C />
                      <b>0</b>
                      <small>{String(label)}</small>
                    </span>
                  );
                })}
              </div>
              <div className="demo-chart">
                <div className="chart-bars">{[35, 58, 42, 72, 61, 86, 67, 95].map((height, index) => <i key={index} style={{ height: `${height}%` }} />)}</div>
                <p>Seus indicadores aparecerão aqui quando sua operação começar.</p>
              </div>
            </div>
          </div>
        </section>

        <HomePlans plans={plans} />

        <section className="final-cta container">
          <div>
            <h2>Seu próximo fornecedor<br />ou cliente pode estar no <span>AcheFood.</span></h2>
            <p>Junte-se a empresas que estão criando novas oportunidades.</p>
          </div>
          <Link href="/cadastro" className="af-btn af-btn-primary">Criar conta gratuitamente <ArrowRight /></Link>
        </section>
      </main>

      <footer id="sobre">
        <div className="container">
          <AcheFoodLogo />
          <p>Quem procura, acha. Quem vende, conecta.</p>
          <span>© 2026 AcheFood. Todos os direitos reservados.</span>
        </div>
      </footer>
    </div>
  );
}
