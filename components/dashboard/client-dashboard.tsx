"use client";
import Link from "next/link";
import {
  BarChart3,
  Bell,
  Building2,
  ChevronDown,
  CircleHelp,
  FileText,
  Flame,
  Handshake,
  Home,
  Import,
  MapPin,
  Menu,
  MessageCircle,
  Package,
  Search,
  Settings,
  Store,
  Target,
  Users,
} from "lucide-react";
import { useState } from "react";
import { AcheFoodLogo } from "@/components/brand/achefood-logo";

const nav = [
  [Home, "Início", "/app/dashboard"],
  [Search, "Buscar produtos", "/app/buscar"],
  [MapPin, "Perto de mim", "/app/perto-de-mim"],
  [Target, "Procurar para mim", "/app/procurar-para-mim"],
  [Flame, "Mais procurados", "/app/mais-procurados"],
  [Package, "Categorias", "/app/categorias"],
  [FileText, "Meus pedidos", "/app/pedidos"],
  [Building2, "Área da empresa", "/app/empresa"],
  [Store, "Meus produtos", "/app/produtos"],
  [Import, "Importar catálogo", "/app/importar"],
  [Target, "Oportunidades", "/app/oportunidades"],
  [Users, "Conexões", "/app/conexoes"],
  [MessageCircle, "Mensagens", "/app/mensagens"],
  [BarChart3, "Planos", "/app/planos"],
  [CircleHelp, "Ajuda e suporte", "/app/suporte"],
] as const;

const metrics = [
  [Package, "Produtos visualizados", "12.450", "#ff6a00", "#fff1e6"],
  [Users, "Fornecedores", "3.280", "#22c55e", "#ebf9f0"],
  [FileText, "Cotações enviadas", "8.760", "#3b82f6", "#edf4ff"],
  [Handshake, "Conexões realizadas", "42", "#7c3aed", "#f4efff"],
] as const;

const recentOpportunities = [
  { name: "Mussarela — 2,5kg", seller: "Supermercado Exemplo", status: "Nova", time: "Há 20 min" },
  { name: "Bacon — Pacote 1kg", seller: "Mercado Bom Preço", status: "Em análise", time: "Há 45 min" },
  { name: "Requeijão — 200g", seller: "Restaurante Sabor", status: "Em andamento", time: "Há 1h" },
];

const popularProducts = [
  { name: "Mussarela Scaia", searches: 431 },
  { name: "Bacon Sabor Mineiro", searches: 291 },
  { name: "Requeijão Scaia", searches: 354 },
  { name: "Presunto Sadia", searches: 288 },
  { name: "Queijo Parmesão", searches: 277 },
];

export function ClientDashboard() {
  const [drawer, setDrawer] = useState(false);

  return (
    <div className="dashboard-shell">
      <aside className={drawer ? "client-sidebar open" : "client-sidebar"}>
        <AcheFoodLogo />

        <div className="profile">
          <span>EO</span>
          <b>
            Eduardo Oliveira
            <small>Comprador</small>
          </b>
        </div>

        <nav>
          {nav.map(([Icon, title, href], index) => (
            <Link className={index === 0 ? "active" : ""} href={href} key={title} onClick={() => setDrawer(false)}>
              <Icon />
              {title}
              {[10, 11, 12].includes(index) && <em>0</em>}
            </Link>
          ))}
        </nav>

        <button type="button">
          <Settings /> Configurações
        </button>
      </aside>

      {drawer && <button className="drawer-backdrop" onClick={() => setDrawer(false)} aria-label="Fechar menu" />}

      <header className="client-top">
        <button type="button" onClick={() => setDrawer(true)} aria-label="Abrir menu">
          <Menu />
        </button>

        <div className="mobile-brand">
          <AcheFoodLogo />
        </div>

        <span />

        <button type="button" aria-label="Notificações"><Bell /></button>
        <button type="button" aria-label="Mensagens"><MessageCircle /></button>
        <div className="avatar">EO</div>
        <ChevronDown />
      </header>

      <main className="dashboard-main">
        <div className="dashboard-heading">
          <div>
            <h1>Olá, Cliente! 👋</h1>
            <p>Bem-vindo ao AcheFood.</p>
          </div>

          <button type="button"><FileText /> Últimos 30 dias <ChevronDown /></button>
        </div>

        <div className="kpi-grid">
          {metrics.map(([Icon, label, value, color, bg]) => (
            <article className="af-card" key={String(label)}>
              <i style={{ color, background: bg }}><Icon /></i>
              <b>{value}</b>
              <span>{label}</span>
            </article>
          ))}
        </div>

        <section className="performance af-card">
          <div className="card-head">
            <h2>Desempenho</h2>
            <div>
              <span className="blue" />Visualizações
              <span className="orange" />Cotações
              <span className="green" />Conexões
            </div>
          </div>

          <div className="chart-panel">
            <div className="chart-grid">
              {[300, 230, 180, 320, 260, 200, 380, 420].map((point, idx) => (
                <div key={idx} className="chart-col">
                  <span style={{ height: `${point}px` }} />
                </div>
              ))}
            </div>
          </div>
        </section>

        <div className="dashboard-columns">
          <section className="af-card data-panel">
            <div className="panel-title-row">
              <h3>Produtos mais procurados</h3>
              <Link href="/app/buscar">Ver todos</Link>
            </div>

            <ol className="popular-list">
              {popularProducts.map((product, index) => (
                <li key={product.name}>
                  <span className="rank">{index + 1}</span>
                  <div className="thumb thumb-one" aria-hidden="true" />
                  <div className="name-block">
                    <strong>{product.name}</strong>
                  </div>
                  <small>{product.searches} buscas</small>
                </li>
              ))}
            </ol>
          </section>

          <section className="af-card data-panel">
            <div className="panel-title-row">
              <h3>Oportunidades recentes</h3>
              <Link href="/app/oportunidades">Ver todas</Link>
            </div>

            <ul className="opportunity-list">
              {recentOpportunities.map((opportunity) => (
                <li key={opportunity.name}>
                  <div className="opportunity-product">
                    <div className="mini-pod" aria-hidden="true" />
                    <div>
                      <strong>{opportunity.name}</strong>
                      <small>{opportunity.seller}</small>
                    </div>
                  </div>
                  <span className={`tag ${opportunity.status.toLowerCase().replace(/\s+/g, "-")}`}>{opportunity.status}</span>
                  <time>{opportunity.time}</time>
                </li>
              ))}
            </ul>
          </section>
        </div>

        <section className="region-banner">
          <div className="map-mini" aria-hidden="true">
            <span className="pin">📍</span>
          </div>

          <div>
            <h2>Encontre fornecedores na sua região</h2>
            <p>Mais agilidade para a sua operação.</p>
          </div>

          <button type="button" className="af-btn af-btn-primary">Explorar fornecedores →</button>
        </section>
      </main>
    </div>
  );
}
