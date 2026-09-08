import "@/components/brand/brand.css";
import "@/components/dashboard/dashboard.css";
import { ClientDashboard } from "@/components/dashboard/client-dashboard";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
export const metadata={title:"Painel do cliente",robots:{index:false,follow:false}};
export const dynamic = "force-dynamic";
type ClientMetrics={views:number;suppliers:number;quotes:number;connections:number};

export default async function Dashboard(){
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?next=/app/dashboard");

  const [{ data: profile }, { data: memberships }] = await Promise.all([
    supabase.from("profiles").select("first_name,last_name,profile_type,onboarding_completed").eq("id", user.id).maybeSingle(),
    supabase.from("company_members").select("company_id,role,companies(trade_name)").eq("user_id", user.id).eq("status", "active").limit(1),
  ]);
  if (!profile?.onboarding_completed || !memberships?.length) redirect("/onboarding");

  const fullName = [profile?.first_name, profile?.last_name].filter(Boolean).join(" ") || user.email?.split("@")[0] || "Cliente";
  const company = memberships?.[0];
  const companyRecord = company?.companies as unknown as { trade_name?: string } | null;
  const companyName = companyRecord?.trade_name;
  const {data}=await supabase.rpc("get_client_dashboard_metrics",{target_company:company.company_id});
  const metrics=(data as ClientMetrics|null)??{views:0,suppliers:0,quotes:0,connections:0};

  return <ClientDashboard user={{ name: fullName, email: user.email ?? "", accountType: profile?.profile_type === "supplier" ? "Fornecedor" : profile?.profile_type === "both" ? "Comprador + Fornecedor" : "Comprador", companyName: companyName ?? null }} metrics={metrics} />
}
