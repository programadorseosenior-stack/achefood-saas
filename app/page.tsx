import "@/components/brand/brand.css";
import "@/components/marketing/landing.css";
import "@/components/commercial/plans.css";
import { LandingPage } from "@/components/marketing/landing-page";
import { getPlans } from "@/lib/commercial/plans";

export const dynamic = "force-dynamic";

export default async function Home() {
  return <LandingPage plans={await getPlans()} />;
}
