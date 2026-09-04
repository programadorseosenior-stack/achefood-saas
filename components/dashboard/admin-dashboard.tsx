"use client";

import { useState } from "react";
import Link from "next/link";
import { AreaChart, Area, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Bell, Building2, ChevronDown, CircleDollarSign, FileCheck2, FileText, Gauge, Handshake, LayoutGrid, LifeBuoy, LogOut, Menu, Package, Settings, ShieldCheck, Tags, Users } from "lucide-react";
import { AcheFoodLogo } from "@/components/brand/achefood-logo";
import { createClient } from "@/lib/supabase/client";

type Props = { adminName: string; metrics: { companies: number; suppliers: number; buyers: number; products: number } };
const nav = [[LayoutGrid,"Dashboard"],[Building2,"Empresas"],[Users,"Fornecedores"],[Users,"Compradores"],[Users,"Usuários"],[Package,"Produtos"],[Tags,"Categorias"],[Gauge,"Oportunidades"],[FileText,"Cotações"],[Handshake,"Conexões"],[ShieldCheck,"Planos"],[FileCheck2,"Assinaturas"],[CircleDollarSign,"Pagamentos"],[FileText,"Relatórios"],[ShieldCheck,"Moderação"],[Bell,"Notificações"],[Settings,"Configurações"],[LifeBuoy,"Suporte"]] as const;
const chart = [{d:"22/04",v:0},{d:"29/04",v:0},{d:"06/05",v:0},{d:"13/05",v:0},{d:"20/05",v:0}];
const tones = ["orange","green","blue","purple"];
const quickActions = [[Building2,"Gerenciar empresas"],[Users,"Gerenciar fornecedores"],[FileCheck2,"Aprovar produtos"],[ShieldCheck,"Gerenciar planos"],[CircleDollarSign,"Relatórios financeiros"],[Settings,"Configurações da plataforma"]] as const;

export function AdminDashboard({adminName,metrics}:Props){
 const [drawer,setDrawer]=useState(false);
 const cards=[[Building2,"Empresas cadastradas",metrics.companies],[Users,"Fornecedores",metrics.suppliers],[Users,"Compradores",metrics.buyers],[Package,"Produtos cadastrados",metrics.products]] as const;
 async function logout(){await createClient().auth.signOut();location.href="/login"}
 return <div className="admin-shell">
  <aside className={drawer?"admin-side open":"admin-side"}><AcheFoodLogo/><nav>{nav.map(([Icon,label],i)=><Link key={label} className={i===0?"active":""} href={i===0?"/admin/dashboard":`/admin/dashboard#${label.toLowerCase()}`} onClick={()=>setDrawer(false)}><Icon/>{label}</Link>)}</nav><button onClick={logout}><LogOut/>Sair</button></aside>
  {drawer&&<button className="admin-backdrop" aria-label="Fechar menu" onClick={()=>setDrawer(false)}/>} 
  <header className="admin-top"><button aria-label="Abrir menu" onClick={()=>setDrawer(true)}><Menu/></button><span/><button aria-label="Notificações"><Bell/><em>3</em></button><div className="admin-avatar">AF</div><div><b>{adminName}</b><small>Super Administrador</small></div><ChevronDown/></header>
  <main className="admin-main"><div className="admin-title"><h1>Painel Administrativo</h1><p>Visão geral da plataforma</p></div>
   <section className="admin-kpis">{cards.map(([Icon,label,value],i)=><article className="af-card" key={label}><i className={tones[i]}><Icon/></i><div><b>{value.toLocaleString("pt-BR")}</b><span>{label}</span></div></article>)}</section>
   <section className="admin-grid top-grid"><article className="af-card admin-panel"><div className="admin-panel-head"><div><h2>Receita mensal (MRR)</h2><strong>R$ 0,00</strong><p>Sem movimentação registrada</p></div><button>Últimos 30 dias <ChevronDown/></button></div><div className="admin-chart"><ResponsiveContainer width="100%" height="100%"><AreaChart data={chart}><defs><linearGradient id="admFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#ff5a00" stopOpacity=".2"/><stop offset="100%" stopColor="#ff5a00" stopOpacity="0"/></linearGradient></defs><CartesianGrid vertical={false} stroke="#edf0f4"/><XAxis dataKey="d" tickLine={false}/><YAxis tickLine={false}/><Tooltip/><Area dataKey="v" stroke="#ff5a00" strokeWidth={3} fill="url(#admFill)"/></AreaChart></ResponsiveContainer></div></article>
    <article className="af-card admin-panel"><h2>Assinaturas por plano</h2><div className="donut-row"><div className="donut"><span><b>0</b>Total</span></div><ul><li><i className="dot blue"/>Grátis <b>0</b></li><li><i className="dot green"/>Essencial <b>0</b></li><li><i className="dot orange"/>Profissional <b>0</b></li><li><i className="dot purple"/>Premium <b>0</b></li></ul></div></article></section>
   <section className="admin-grid"><article className="af-card admin-panel"><h2>Atividade recente</h2><div className="admin-empty"><FileText/><b>Nenhuma atividade recente</b><span>Os eventos administrativos aparecerão aqui.</span></div></article><article className="af-card admin-panel"><h2>Ações rápidas</h2><div className="quick-list">{quickActions.map(([Icon,label])=><Link href={`/admin/dashboard#${label.toLowerCase()}`} key={label}><i><Icon/></i>{label}<span>›</span></Link>)}</div></article></section>
   <section className="admin-grid compact"><article className="af-card admin-panel"><h2>Top categorias</h2><div className="admin-empty"><Tags/><b>Sem dados de busca</b><span>O ranking será calculado com o uso da plataforma.</span></div></article><article className="af-card admin-panel"><h2>Regiões com mais atividade</h2><div className="admin-empty"><Gauge/><b>Sem atividade regional</b><span>Os dados aparecerão após as primeiras interações.</span></div></article></section>
  </main>
  <nav className="admin-bottom"><Link className="active" href="/admin/dashboard"><LayoutGrid/>Dashboard</Link><Link href="#empresas"><Building2/>Empresas</Link><Link href="#usuarios"><Users/>Usuários</Link><Link href="#relatorios"><Gauge/>Relatórios</Link><Link href="#mais"><Menu/>Mais</Link></nav>
 </div>
}
