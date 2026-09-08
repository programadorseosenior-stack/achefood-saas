import { createServerClient } from "@supabase/ssr";
import { NextRequest, NextResponse } from "next/server";
import { safeInternalPath } from "@/lib/auth/safe-redirect";

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  const requestedNext = request.nextUrl.searchParams.get("next");
  const recovery = request.nextUrl.searchParams.get("flow") === "recovery";
  const next = recovery ? "/recuperar-senha/nova" : safeInternalPath(requestedNext);
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const failed = () => NextResponse.redirect(new URL("/login?auth_error=callback", request.url));
  if (!code || !supabaseUrl || !supabaseKey || request.nextUrl.searchParams.has("error")) return failed();
  const response = NextResponse.redirect(new URL(next, request.url));
  const supabase = createServerClient(supabaseUrl, supabaseKey, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (cookies) => cookies.forEach(({ name, value, options }) => response.cookies.set(name, value, options)),
    },
  });
  try {
    const { data, error } = await supabase.auth.exchangeCodeForSession(code);
    if (error || !data.session) return failed();
    if (recovery) response.cookies.set("achefood_recovery", "1", { httpOnly: true, secure: true, sameSite: "lax", path: "/recuperar-senha/nova", maxAge: 600 });
    return response;
  } catch {
    return failed();
  }
}
