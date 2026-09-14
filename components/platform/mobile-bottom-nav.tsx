"use client";

import Link from "next/link";
import { Flame, Home, Search, UserRound } from "lucide-react";

const items = [
  [Home, "Início", "/app/dashboard"],
  [Search, "Buscar", "/app/buscar"],
  [Flame, "Mais procurados", "/app/mais-procurados"],
  [UserRound, "Perfil", "/app/perfil"],
] as const;

export function MobileBottomNav({ active }: { active: string }) {
  return (
    <nav className="bottom-nav" aria-label="Navegação móvel">
      {items.map(([Icon, label, href]) => (
        <Link className={active === href ? "active" : ""} href={href} key={href} aria-current={active === href ? "page" : undefined}>
          <Icon aria-hidden="true" />
          <span>{label}</span>
        </Link>
      ))}
    </nav>
  );
}
