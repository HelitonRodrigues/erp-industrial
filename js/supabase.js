// ============================================================
// ERP INDUSTRIAL — SUPABASE.JS
// Cliente Supabase único para todos os módulos
// ============================================================

const SUPABASE_URL = 'https://cskcvntadptysfrvgczj.supabase.co';
const SUPABASE_KEY = 'sb_publishable_f5WXhVto_-zoX6Vrg33tRg_ooiIYh5c';

const _supabase = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
