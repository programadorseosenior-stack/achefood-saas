import { redirect } from "next/navigation";
import { PlatformWorkspace, type WorkspaceData } from "@/components/platform/platform-workspace";
import { createClient } from "@/lib/supabase/server";
import "@/components/brand/brand.css";
import "@/components/dashboard/dashboard.css";
import "@/components/platform/platform.css";

export const dynamic = "force-dynamic";
export const metadata = { title: "AcheFood | Plataforma", robots: { index: false, follow: false } };
const supported = new Set(["produtos", "buscar", "oportunidades", "cotacoes", "pedidos", "conexoes", "mensagens"]);
const aliases: Record<string, string> = {
  "perto-de-mim": "buscar",
  "mais-procurados": "buscar",
  categorias: "buscar",
  "procurar-para-mim": "oportunidades",
  empresa: "produtos",
  importar: "produtos",
};

export default async function PlatformRoute({ params }: { params: Promise<{ slug?: string[] }> }) {
  const requestedRoute = (await params).slug?.[0] ?? "buscar";
  if (requestedRoute === "planos") redirect("/planos");
  const route = aliases[requestedRoute] ?? requestedRoute;
  if (!supported.has(route)) redirect("/app/dashboard");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/login?next=/app/${route}`);
  const [{ data: profile }, { data: memberships }] = await Promise.all([
    supabase.from("profiles").select("first_name,last_name,profile_type,onboarding_completed").eq("id", user.id).maybeSingle(),
    supabase.from("company_members").select("company_id,role,companies(trade_name)").eq("user_id", user.id).eq("status", "active").limit(1),
  ]);
  if (!profile?.onboarding_completed || !memberships?.length) redirect("/onboarding");
  const member = memberships[0];
  const company = member.companies as unknown as { trade_name?: string } | null;
  const data: WorkspaceData = { categories: [], products: [], opportunities: [], quotes: [], connections: [], conversations: [], messages: [] };
  const section = route === "pedidos" ? "cotacoes" : route;
  const { data: categories } = await supabase.from("categories").select("id,name,slug").eq("is_active", true).order("name");
  data.categories = categories ?? [];
  if (section === "produtos") {
    const { data: rows } = await supabase.from("products").select("id,name,description,sku,unit,price,currency,min_order_quantity,status,image_url,category_id,categories(name),created_at").eq("company_id", member.company_id).order("created_at", { ascending: false }); data.products = rows ?? [];
  } else if (section === "buscar") {
    const { data: rows } = await supabase.from("products").select("id,name,description,unit,price,currency,min_order_quantity,image_url,company_id,companies(trade_name,city,state),categories(name)").eq("status", "active").order("created_at", { ascending: false }).limit(100); data.products = rows ?? [];
  } else if (section === "oportunidades") {
    const { data: rows } = await supabase.from("opportunities").select("id,buyer_company_id,title,description,status,delivery_city,delivery_state,closes_at,published_at,categories(name),opportunity_items(id,product_name,description,quantity,unit)").order("created_at", { ascending: false }); data.opportunities = rows ?? [];
  } else if (section === "cotacoes") {
    const { data: rows } = await supabase.from("quotes").select("id,opportunity_id,supplier_company_id,status,notes,currency,subtotal,shipping_amount,total_amount,valid_until,submitted_at,opportunities(title,buyer_company_id),companies(trade_name),quote_items(id,description,quantity,unit,unit_price,total_price)").order("created_at", { ascending: false }); data.quotes = rows ?? [];
  } else if (section === "conexoes") {
    const { data: rows } = await supabase.from("connections").select("id,buyer_company_id,supplier_company_id,initiated_by_company_id,status,created_at,buyer:companies!connections_buyer_company_id_fkey(trade_name),supplier:companies!connections_supplier_company_id_fkey(trade_name)").order("created_at", { ascending: false }); data.connections = rows ?? [];
  } else if (section === "mensagens") {
    const { data: conversations } = await supabase.from("conversations").select("id,connection_id,updated_at,connections(buyer_company_id,supplier_company_id,status,buyer:companies!connections_buyer_company_id_fkey(trade_name),supplier:companies!connections_supplier_company_id_fkey(trade_name))").order("updated_at", { ascending: false }); data.conversations = conversations ?? [];
    if (conversations?.[0]?.id) { const { data: messages } = await supabase.from("messages").select("id,conversation_id,sender_company_id,body,read_at,created_at").eq("conversation_id", conversations[0].id).order("created_at"); data.messages = messages ?? []; }
  }
  const name = [profile.first_name, profile.last_name].filter(Boolean).join(" ") || user.email?.split("@")[0] || "Cliente";
  return <PlatformWorkspace section={section} companyId={member.company_id} user={{ name, accountType: profile.profile_type === "supplier" ? "Fornecedor" : profile.profile_type === "both" ? "Comprador + Fornecedor" : "Comprador", companyName: company?.trade_name ?? "Minha empresa" }} data={data} />;
}
