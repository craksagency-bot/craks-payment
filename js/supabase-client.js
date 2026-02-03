// CRAKS Payment Management System - Supabase Client
// Replace these with your actual Supabase project credentials

const SUPABASE_URL = 'https://poilgduwlqtxjiudarew.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvaWxnZHV3bHF0eGppdWRhcmV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxMjU1ODIsImV4cCI6MjA4NTcwMTU4Mn0.ixPxRwiLafCoWNucOdkCoh3BqeQaiadM3r9B5lQKCSg';

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
