import type { Plan } from "./types";

export async function getPlans(): Promise<Plan[]> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return [];

  try {
    const response = await fetch(
      `${url}/rest/v1/plans?select=*,plan_features(*)&is_active=eq.true&order=sort_order.asc`,
      { headers: { apikey: key, Authorization: `Bearer ${key}` }, next: { revalidate: 300 } },
    );
    if (!response.ok) return [];
    return (await response.json()) as Plan[];
  } catch {
    return [];
  }
}
