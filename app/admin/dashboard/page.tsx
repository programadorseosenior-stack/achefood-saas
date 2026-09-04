import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import "@/components/brand/brand.css";
import "@/components/dashboard/admin-dashboard.css";
import { AdminDashboard } from "@/components/dashboard/admin-dashboard";

export const metadata={title:"Painel administrativo",robots:{index:false,follow:false}};
export const dynamic="force-dynamic";
export default async function AdminPage(){const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login?next=/admin/dashboard");const {data:admin}=await supabase.from("admin_members").select("role,status").eq("user_id",user.id).maybeSingle();if(!admin)redirect("/app/dashboard");if(admin.status!=="active")redirect("/admin/primeiro-acesso");return <AdminDashboard adminName={user.user_metadata?.first_name||"Admin"} metrics={{companies:0,suppliers:0,buyers:0,products:0}}/>}
