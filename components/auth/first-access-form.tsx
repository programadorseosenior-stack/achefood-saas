"use client";
import { Eye,EyeOff,LockKeyhole } from "lucide-react";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export function FirstAccessForm(){
 const [show,setShow]=useState(false);const [loading,setLoading]=useState(false);const [error,setError]=useState("");
 async function submit(event:React.FormEvent<HTMLFormElement>){event.preventDefault();setError("");const form=new FormData(event.currentTarget);const password=String(form.get("password"));const confirm=String(form.get("confirm"));if(password!==confirm){setError("As senhas não coincidem.");return}setLoading(true);try{const supabase=createClient();const {error:updateError}=await supabase.auth.updateUser({password});if(updateError)throw updateError;const {error:completeError}=await supabase.rpc("complete_admin_first_access");if(completeError)throw completeError;window.location.href="/admin/dashboard"}catch(err){setError(err instanceof Error?err.message:"Não foi possível concluir o primeiro acesso.")}finally{setLoading(false)}}
 return <div className="auth-card af-card"><h2>Defina sua <span>senha</span></h2><p>Primeiro acesso administrativo seguro.</p><form onSubmit={submit}><label>Nova senha<div className="input-wrap"><LockKeyhole/><input required minLength={8} type={show?"text":"password"} name="password" autoComplete="new-password" placeholder="Mínimo de 8 caracteres"/><button type="button" onClick={()=>setShow(v=>!v)} aria-label={show?"Ocultar senha":"Mostrar senha"}>{show?<EyeOff/>:<Eye/>}</button></div></label><label>Confirmar nova senha<div className="input-wrap"><LockKeyhole/><input required minLength={8} type={show?"text":"password"} name="confirm" autoComplete="new-password" placeholder="Repita sua senha"/></div></label>{error&&<div role="alert" className="auth-error">{error}</div>}<button className="af-btn af-btn-primary submit" disabled={loading}>{loading?"Salvando...":"Ativar acesso administrativo"}</button></form></div>
}
