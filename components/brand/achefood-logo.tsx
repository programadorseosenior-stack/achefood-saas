import Image from "next/image";
import Link from "next/link";

export function AcheFoodLogo({ compact = false }: { compact?: boolean }) {
  return (
    <Link href="/" className={`brand-logo${compact ? " brand-logo-compact" : ""}`} aria-label="AcheFood — Encontrou. Conectou. Resolveu.">
      <span className="brand-artwork">
        <Image className="brand-symbol" src="/brand/achefood-symbol.png" alt="" width={611} height={415} sizes={compact ? "52px" : "58px"} />
        {!compact && <span className="brand-copy">
          <Image className="brand-wordmark" src="/brand/achefood-wordmark.png" alt="AcheFood" width={680} height={143} sizes="150px" priority />
          <Image className="brand-tagline" src="/brand/achefood-tagline.png" alt="Encontrou. Conectou. Resolveu." width={615} height={53} sizes="150px" />
        </span>}
      </span>
    </Link>
  );
}
