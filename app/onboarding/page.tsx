import Link from "next/link";
import { AcheFoodLogo } from "@/components/brand/achefood-logo";
import "@/components/brand/brand.css";
import "@/components/auth/auth.css";
export default function Onboarding(){return <main style={{minHeight:"100vh",display:"grid",placeItems:"center",padding:24}}><section className="af-card" style={{padding:40,width:"min(100%,680px)"}}><AcheFoodLogo/><h1>Configure sua empresa</h1><p className="muted">O onboarding transacional será conectado ao Supabase após a aplicação da migration multiempresa.</p><div className="form-grid"><label>Razão social<input/></label><label>Nome fantasia<input/></label><label>CNPJ<input/></label><label>Telefone<input/></label><label>CEP<input/></label><label>Cidade<input/></label><label>Estado<input/></label></div><Link href="/app/dashboard" className="af-btn af-btn-primary" style={{marginTop:24}}>Continuar</Link></section></main>}
