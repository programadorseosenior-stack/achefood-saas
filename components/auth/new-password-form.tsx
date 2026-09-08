"use client";

import { Eye, EyeOff, LockKeyhole } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";

export function NewPasswordForm({ recoveryAuthorized }: { recoveryAuthorized: boolean }) {
  const [ready, setReady] = useState(false);
  const [show, setShow] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(recoveryAuthorized ? "" : "Este link é inválido ou expirou. Solicite um novo e-mail de recuperação.");

  useEffect(() => {
    if (!recoveryAuthorized) return;
    createClient().auth.getSession().then(({ data }) => {
      setReady(Boolean(data.session));
      if (!data.session) setError("Este link é inválido ou expirou. Solicite um novo e-mail de recuperação.");
    }).catch(() => setError("Não foi possível validar o link. Solicite um novo e-mail de recuperação."));
  }, [recoveryAuthorized]);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    const form = new FormData(event.currentTarget);
    const password = String(form.get("password"));
    const confirm = String(form.get("confirm"));
    if (password !== confirm) { setError("As senhas não coincidem."); return; }
    setLoading(true);
    try {
      const supabase = createClient();
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) throw updateError;
      await supabase.auth.signOut();
      window.location.href = "/login?password_updated=1";
    } catch (cause) {
      setError(cause instanceof Error && cause.message.toLowerCase().includes("password") ? "A senha não atende aos requisitos de segurança. Use pelo menos 8 caracteres." : "Não foi possível alterar a senha. Solicite um novo link.");
      setLoading(false);
    }
  }

  return <div className="auth-card af-card"><h2>Crie sua nova <span>senha</span></h2><p>Use no mínimo 8 caracteres e não reutilize uma senha antiga.</p><form onSubmit={submit}><label>Nova senha<div className="input-wrap"><LockKeyhole/><input required minLength={8} type={show ? "text" : "password"} name="password" autoComplete="new-password" placeholder="Mínimo de 8 caracteres"/><button type="button" onClick={() => setShow(value => !value)} aria-label={show ? "Ocultar senha" : "Mostrar senha"}>{show ? <EyeOff/> : <Eye/>}</button></div></label><label>Confirmar nova senha<div className="input-wrap"><LockKeyhole/><input required minLength={8} type={show ? "text" : "password"} name="confirm" autoComplete="new-password" placeholder="Repita sua senha"/></div></label>{error && <div role="alert" className="auth-error">{error}</div>}<button className="af-btn af-btn-primary submit" disabled={!ready || loading}>{loading ? "Salvando..." : ready ? "Salvar nova senha" : "Validando link..."}</button></form>{!ready && <div className="signup-copy"><Link href="/recuperar-senha">Solicitar novo link</Link></div>}</div>;
}
