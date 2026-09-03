import type { Metadata } from "next";
import "@/components/brand/brand.css";
import "@/components/auth/auth.css";
import { AuthShell } from "@/components/auth/auth-shell";
import { LoginForm } from "@/components/auth/login-form";

export const metadata: Metadata = { title: "Entrar", robots: { index: false, follow: false } };
export default async function LoginPage({ searchParams }: { searchParams: Promise<{ auth_error?: string }> }) {
  const params = await searchParams;
  return <AuthShell>{params.auth_error === "callback" && <p role="alert" className="auth-error">Não foi possível confirmar seu acesso. O link pode ter expirado. Tente entrar novamente.</p>}<LoginForm/></AuthShell>;
}
