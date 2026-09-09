import { redirect, notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { AdminCrud } from "@/components/admin/admin-crud";
import "@/components/brand/brand.css";
import "@/components/admin/admin-crud.css";

export const dynamic = "force-dynamic";
export const metadata = { title: "Gestão administrativa", robots: { index: false, follow: false } };

const modules = ["empresas", "usuarios", "produtos", "planos", "relatorios"] as const;
type ModuleName = (typeof modules)[number];

export default async function AdminModulePage({ params }: { params: Promise<{ module: string }> }) {
  const { module } = await params;
  if (!modules.includes(module as ModuleName)) notFound();
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/login?next=${encodeURIComponent(`/admin/${module}`)}`);
  const { data: admin } = await supabase.from("admin_members").select("role,status").eq("user_id", user.id).maybeSingle();
  if (!admin || admin.role !== "super_admin") redirect("/app/dashboard");
  if (admin.status !== "active") redirect("/admin/primeiro-acesso");

  return <AdminCrud module={module as ModuleName} adminName={user.user_metadata?.first_name || "Admin"} />;
}
