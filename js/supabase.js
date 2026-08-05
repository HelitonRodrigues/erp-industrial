// ============================================================
// ERP INDUSTRIAL — SUPABASE.JS
// Cliente Supabase único para todos os módulos
// ============================================================

const SUPABASE_URL = 'https://zodgbitbflkepbszshmu.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGdiaXRiZmxrZXBic3pzaG11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjYwNjgsImV4cCI6MjA5MTY0MjA2OH0.iWROA5X7CkxOunt7Cn46wWODa7SQ5nU8OJcD52NhCgA';

const _supabase = supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
  realtime: { enabled: false },
  global: { headers: { 'x-client-info': 'erp-industrial' } }
});
