import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export const metadata={title:"Painel administrativo",robots:{index:false,follow:false}};
export const dynamic="force-dynamic";
export default async function AdminDashboard(){const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login?next=/admin/dashboard");const {data:admin}=await supabase.from("admin_members").select("role,status").eq("user_id",user.id).maybeSingle();if(!admin)redirect("/app/dashboard");if(admin.status!=="active")redirect("/admin/primeiro-acesso");return <main style={{minHeight:"100vh",display:"grid",placeItems:"center",padding:24,background:"#f7f9fc"}}><section className="af-card" style={{padding:36,maxWidth:620,textAlign:"center"}}><h1>Painel Administrativo</h1><p>Seu acesso de Super Administrador está ativo. O dashboard completo será conectado na próxima etapa.</p></section></main>}
