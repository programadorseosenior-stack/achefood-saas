import Link from "next/link";
import { AcheFoodLogo } from "@/components/brand/achefood-logo";
import "@/components/brand/brand.css";

export default async function PlatformRoute({params}:{params:Promise<{slug?:string[]}>}){const {slug}=await params;const title=(slug?.at(-1)||"app").replaceAll("-"," ");return <main style={{minHeight:"100vh",display:"grid",placeItems:"center",padding:24}}><section className="af-card" style={{padding:40,maxWidth:620,textAlign:"center"}}><AcheFoodLogo/><h1 style={{textTransform:"capitalize",marginTop:32}}>{title}</h1><p className="muted">Esta rota já está estruturada para a próxima fatia funcional do AcheFood. O dashboard, Home e autenticação são a prioridade estabilizada neste ciclo.</p><Link className="af-btn af-btn-primary" href="/app/dashboard">Voltar ao painel</Link></section></main>}
