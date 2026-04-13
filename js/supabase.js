// ============================================================
// ERP INDUSTRIAL — SUPABASE.JS
// Cliente Supabase único para todos os módulos
// ============================================================

const SUPABASE_URL = 'https://zodgbitbflkepbszshmu.supabase.co';
const SUPABASE_KEY = 'sb_publishable_ioEty5Ly9AeNzDHemcV_Hw_uhIejLj6';

const _supabase = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
