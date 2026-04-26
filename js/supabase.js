// ============================================================
// ERP INDUSTRIAL — SUPABASE.JS
// Cliente Supabase único para todos os módulos
// ============================================================

const SUPABASE_URL = 'https://zodgbitbflkepbszshmu.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGdiaXRiZmxrZXBic3pzaG11Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjA2NjA2OCwiZXhwIjoyMDkxNjQyMDY4fQ.cclkLlP8v7IMH4AXGliDNxBEyn5Sg2VxyHIEEsv_yc8';

const _supabase = supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
  realtime: { enabled: false },
  global: { headers: { 'x-client-info': 'erp-industrial' } }
});
