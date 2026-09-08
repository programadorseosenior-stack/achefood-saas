import type { Metadata } from "next";
import { AuthShell } from "@/components/auth/auth-shell";
import { NewPasswordForm } from "@/components/auth/new-password-form";
import { cookies } from "next/headers";

export const metadata: Metadata = { title: "Nova senha | AcheFood", robots: { index: false, follow: false } };

export default async function NovaSenha() { const authorized=(await cookies()).get("achefood_recovery")?.value==="1"; return <AuthShell><NewPasswordForm recoveryAuthorized={authorized}/></AuthShell>; }
