"use client";

import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { SplitText } from "gsap/SplitText";
import type { RefObject } from "react";
import { MOTION } from "./tokens";

gsap.registerPlugin(useGSAP, ScrollTrigger, SplitText);

type MotionPage = "home" | "login";

function revealSections(root: HTMLElement, distance: number, duration: number) {
  const sections = gsap.utils.toArray<HTMLElement>(
    ".how, .audience, .supplier-search, .wanted, .dashboard-demo, .commercial-section, .final-cta",
    root,
  );

  sections.forEach((section) => {
    const title = section.querySelector<HTMLElement>(".section-title, .commercial-heading");
    const items = section.querySelectorAll<HTMLElement>(
      ".steps article, .audience-grid > article, .supplier-card, .demo-kpis > span, .demo-board, .commercial-card, .final-cta > *",
    );
    const timeline = gsap.timeline({
      scrollTrigger: { trigger: section, start: "top 82%", once: true },
      defaults: { ease: MOTION.easeOut },
    });
    if (title) timeline.from(title, { autoAlpha: 0, y: distance, duration });
    if (items.length) timeline.from(items, { autoAlpha: 0, y: distance, scale: 0.98, duration, stagger: MOTION.staggerNormal }, "-=0.25");
  });
}

function homeMotion(root: HTMLElement, isDesktop: boolean) {
  const heroTitle = root.querySelector<HTMLElement>(".hero-copy h1");
  const split = heroTitle
    ? SplitText.create(heroTitle, { type: "lines", mask: "lines", aria: "auto" })
    : null;
  const timeline = gsap.timeline({ defaults: { ease: MOTION.easeOut } });

  timeline
    .from(".marketing-header .brand", { autoAlpha: 0, x: -20, scale: 0.96, duration: 0.6 })
    .from(".marketing-header nav > *, .header-actions > *", { autoAlpha: 0, y: -12, duration: MOTION.normal, stagger: 0.06 }, 0.08)
    .from(".hero .eyebrow", { autoAlpha: 0, y: -8, scale: 0.96, duration: 0.5 }, 0.2)
    .from(split?.lines ?? [], { autoAlpha: 0, yPercent: 110, duration: MOTION.medium, stagger: 0.1 }, 0.28)
    .from(".hero-copy > p", { autoAlpha: 0, y: 20, duration: 0.6 }, 0.6)
    .from(".hero-actions > *", { autoAlpha: 0, y: 15, duration: 0.55, stagger: 0.08 }, 0.7)
    .from(".product-preview", { autoAlpha: 0, x: isDesktop ? 35 : 0, y: isDesktop ? 0 : 30, scale: 0.96, duration: 1 }, 0.78)
    .from(".trust-row > *", { autoAlpha: 0, y: 15, scale: 0.97, duration: 0.5, stagger: 0.1 }, 0.9);

  if (isDesktop) {
    gsap.to(".product-preview", { y: 4, duration: 4.6, repeat: -1, yoyo: true, ease: "sine.inOut" });
  }
  revealSections(root, isDesktop ? 30 : 22, isDesktop ? 0.7 : 0.56);
}

function loginMotion(root: HTMLElement, isDesktop: boolean) {
  const title = root.querySelector<HTMLElement>(".auth-brand-copy h1");
  const split = title ? SplitText.create(title, { type: "lines", mask: "lines", aria: "auto" }) : null;
  const timeline = gsap.timeline({ defaults: { ease: MOTION.easeOut } });

  timeline
    .from(".auth-brand-header .brand", { autoAlpha: 0, y: -15, duration: 0.6 })
    .from(split?.lines ?? [], { autoAlpha: 0, yPercent: 110, duration: 0.72, stagger: 0.1 }, 0.1)
    .from(".auth-brand-copy .orange-line, .auth-brand-copy p", { autoAlpha: 0, y: 15, duration: 0.55, stagger: 0.07 }, 0.25)
    .from(".map-core", { autoAlpha: 0, scale: 0.65, duration: 0.6, ease: "back.out(1.4)" }, 0.35)
    .from(".network-node", { autoAlpha: 0, scale: 0, duration: 0.4, stagger: 0.07 }, 0.4)
    .from(".float-card", { autoAlpha: 0, scale: 0.92, y: 15, duration: 0.55, stagger: 0.12 }, 0.45)
    .from(".auth-brand-panel blockquote", { autoAlpha: 0, y: 15, duration: 0.55 }, 0.52)
    .from(".auth-card", { autoAlpha: 0, y: 20, scale: 0.985, duration: 0.75 }, 0.35)
    .from(".auth-card > *", { autoAlpha: 0, y: 8, duration: 0.34, stagger: MOTION.staggerFast }, 0.5)
    .from(".auth-legal", { autoAlpha: 0, duration: 0.4 }, 0.8);

  if (isDesktop) {
    [4.2, 4.8, 5.2].forEach((duration, index) => {
      gsap.to(`.float-card.f${index + 1}`, { y: index % 2 ? 3 : -3, duration, repeat: -1, yoyo: true, ease: "sine.inOut" });
    });
  }
}

export function usePageMotion(scope: RefObject<HTMLElement | null>, page: MotionPage) {
  useGSAP(() => {
    const root = scope.current;
    if (!root) return;
    const media = gsap.matchMedia();
    media.add(
      {
        desktop: "(min-width: 769px)",
        mobile: "(max-width: 768px)",
        reduced: "(prefers-reduced-motion: reduce)",
      },
      (context) => {
        const { desktop, reduced } = context.conditions as { desktop: boolean; mobile: boolean; reduced: boolean };
        if (reduced) {
          gsap.set(root.querySelectorAll("*"), { clearProps: "transform,opacity,visibility" });
          return;
        }
        if (page === "home") homeMotion(root, desktop);
        else loginMotion(root, desktop);
      },
      root,
    );
    document.fonts.ready.then(() => ScrollTrigger.refresh());
    return () => media.revert();
  }, { scope });
}
