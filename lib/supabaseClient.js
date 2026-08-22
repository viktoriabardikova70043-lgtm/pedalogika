import { createClient } from "@supabase/supabase-js";

// Значения берутся из .env.local (см. README) — никогда не хранить ключи в коде
export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);
