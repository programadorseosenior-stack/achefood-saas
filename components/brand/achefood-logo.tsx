import Link from "next/link";
import { ShoppingBag } from "lucide-react";

export function AcheFoodLogo({ compact = false }: { compact?: boolean }) {
  return (
    <Link href="/" className="brand-logo" aria-label="AcheFood — página inicial">
      <span className="brand-mark"><ShoppingBag aria-hidden="true" /><b>A</b></span>
      {!compact && <span>Ache<strong>Food</strong><small>Conecte-se. Gere negócios.</small></span>}
    </Link>
  );
}
