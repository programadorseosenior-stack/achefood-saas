import "@/components/brand/brand.css";
import "@/components/auth/auth.css";
import { AuthShell } from "@/components/auth/auth-shell";
import { FirstAccessForm } from "@/components/auth/first-access-form";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export const metadata={title:"Primeiro acesso administrativo",robots:{index:false,follow:false}};
export const dynamic="force-dynamic";
export default async function FirstAccess(){const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login?next=/admin/primeiro-acesso");const {data:admin}=await supabase.from("admin_members").select("role,status").eq("user_id",user.id).maybeSingle();if(!admin)redirect("/app/dashboard");if(admin.status==="active")redirect("/admin/dashboard");return <AuthShell><FirstAccessForm/></AuthShell>}
