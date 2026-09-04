import "@/components/brand/brand.css";
import "@/components/auth/auth.css";
import {redirect} from "next/navigation";
import {OnboardingForm} from "@/components/auth/onboarding-form";
import {createClient} from "@/lib/supabase/server";
export const dynamic="force-dynamic";
export default async function Onboarding(){const supabase=await createClient();const{data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login?next=/onboarding");const{data:profile}=await supabase.from("profiles").select("onboarding_completed").eq("id",user.id).maybeSingle();if(profile?.onboarding_completed)redirect("/app/dashboard");return <OnboardingForm/>}
