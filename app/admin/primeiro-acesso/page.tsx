import "@/components/brand/brand.css";
import "@/components/auth/auth.css";
import { AuthShell } from "@/components/auth/auth-shell";
import { FirstAccessGate } from "@/components/auth/first-access-gate";

export const metadata={title:"Primeiro acesso administrativo",robots:{index:false,follow:false}};
export default function FirstAccess(){return <AuthShell><FirstAccessGate/></AuthShell>}
