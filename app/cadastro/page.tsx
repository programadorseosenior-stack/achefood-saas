import { Suspense } from "react";
import "@/components/brand/brand.css";
import "@/components/auth/auth.css";
import { AuthShell } from "@/components/auth/auth-shell";
import { SignupForm } from "@/components/auth/signup-form";
export default function Cadastro(){return <AuthShell><Suspense><SignupForm/></Suspense></AuthShell>}
