"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { FirstAccessForm } from "@/components/auth/first-access-form";

type GateState = "loading" | "ready" | "invalid";

export function FirstAccessGate() {
  const [state, setState] = useState<GateState>("loading");

  useEffect(() => {
    const supabase = createClient();
    let active = true;

    async function validateSession() {
      const { data: { session } } = await supabase.auth.getSession();

      if (!active) return;
      if (!session) {
        setState("invalid");
        return;
      }

      const { data: admin } = await supabase
        .from("admin_members")
        .select("status")
        .eq("user_id", session.user.id)
        .maybeSingle();

      if (!active) return;
      if (!admin) {
        window.location.replace("/app/dashboard");
        return;
      }
      if (admin.status === "active") {
        window.location.replace("/admin/dashboard");
        return;
      }

      setState("ready");
    }

    void validateSession();
    const { data: listener } = supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY" || event === "SIGNED_IN") {
        void validateSession();
      }
    });

    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  if (state === "loading") {
    return <div className="auth-card af-card"><p>Validando seu acesso seguro...</p></div>;
  }

  if (state === "invalid") {
    return (
      <div className="auth-card af-card">
        <h2>Link <span>inválido</span></h2>
        <p>Solicite um novo e-mail de primeiro acesso e abra somente o link mais recente.</p>
      </div>
    );
  }

  return <FirstAccessForm />;
}
