"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Eye, EyeOff, LockKeyhole, Mail } from "lucide-react";
import { useState } from "react";
import { createClient, isSupabaseConfigured } from "@/lib/supabase/client";
import { safeInternalPath } from "@/lib/auth/safe-redirect";

export function LoginForm() {
  const params = useSearchParams();
  const [show, setShow] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError("");
    setLoading(true);

    const data = new FormData(e.currentTarget);

    try {
      const supabase = createClient();
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: String(data.get("email")),
        password: String(data.get("password")),
      });

      if (authError) throw authError;
      const { data: admin, error: adminError } = await supabase
        .from("admin_members")
        .select("role,status")
        .eq("user_id", authData.user.id)
        .maybeSingle();
      if (adminError) throw new Error(`Não foi possível validar seu perfil de acesso: ${adminError.message}`);
      const requestedNext = params.get("next") === "/app/admin" ? "/admin/dashboard" : params.get("next");
      const destination = admin?.role === "super_admin" && admin.status === "active" ? "/admin/dashboard" : admin?.role === "super_admin" ? "/admin/primeiro-acesso" : "/app/dashboard";
      window.location.href = requestedNext ? safeInternalPath(requestedNext, destination) : destination;
    } catch (err) {
      setError(err instanceof Error && err.message.startsWith("Não foi possível validar") ? err.message : "E-mail ou senha inválidos. Se necessário, confirme seu e-mail ou recupere a senha.");
    } finally {
      setLoading(false);
    }
  }

  async function google() {
    setError("");
    try {
      const supabase = createClient();
      const requestedNext = params.get("next");
      const safeNext = safeInternalPath(requestedNext);
      const { error: oauthError } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo: `${location.origin}/auth/callback?next=${encodeURIComponent(safeNext)}` },
      });
      if (oauthError) throw oauthError;
    } catch (err) {
      setError(err instanceof Error ? err.message : "Google indisponível.");
    }
  }

  return (
    <div className="auth-card af-card">
      <h2>Bem-vindo ao Ache<span>Food</span></h2>
      <p>Entre na sua conta para continuar.</p>

      <button className="google-btn" onClick={google} disabled={!isSupabaseConfigured() || loading}>
        <b>G</b> Continuar com Google
      </button>

      <div className="or"><span />ou continue com e-mail<span /></div>

      <form onSubmit={submit}>
        <label>
          E-mail
          <div className="input-wrap">
            <Mail />
            <input required type="email" name="email" placeholder="seu@email.com" autoComplete="email" />
          </div>
        </label>

        <label>
          Senha
          <div className="input-wrap">
            <LockKeyhole />
            <input required minLength={6} type={show ? "text" : "password"} name="password" placeholder="Sua senha" autoComplete="current-password" />
            <button type="button" onClick={() => setShow((v) => !v)} aria-label={show ? "Ocultar senha" : "Mostrar senha"}>
              {show ? <EyeOff /> : <Eye />}
            </button>
          </div>
        </label>

        <div className="remember">
          <label><input type="checkbox" name="remember" /> Lembrar de mim</label>
          <Link href="/recuperar-senha">Esqueci minha senha</Link>
        </div>

        {error && <div role="alert" className="auth-error">{error}</div>}
        {!isSupabaseConfigured() && <div className="auth-notice">Modo visual: configure o Supabase no <code>.env.local</code> para ativar o login.</div>}

        <button className="af-btn af-btn-primary submit" disabled={loading}>
          {loading ? "Entrando..." : "Entrar"}
        </button>
      </form>

      <div className="signup-copy">
        Ainda não possui uma conta?<br />
        <Link href="/cadastro">Criar conta gratuitamente</Link>
      </div>
    </div>
  );
}
