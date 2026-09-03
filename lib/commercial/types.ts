export type PlanFeature = {
  feature_key: string;
  enabled: boolean;
  limit_value: number | null;
  config_json: Record<string, unknown> | null;
};

export type Plan = {
  id: string;
  slug: string;
  name: string;
  description: string;
  price_monthly: number | null;
  product_limit: number | null;
  included_users: number | null;
  trial_available: boolean;
  is_free: boolean;
  is_enterprise: boolean;
  is_featured: boolean;
  is_active: boolean;
  sort_order: number;
  plan_features: PlanFeature[];
};
