import type { Metadata } from "next";
import { AuthShell } from "@/components/auth/auth-shell";
import { NewPasswordForm } from "@/components/auth/new-password-form";

export const metadata: Metadata = { title: "Nova senha | AcheFood", robots: { index: false, follow: false } };

export default function NovaSenha() { return <AuthShell><NewPasswordForm/></AuthShell>; }
