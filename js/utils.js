// CRAKS Payment Management System - Utilities

// Format currency (LKR)
function formatCurrency(amount) {
  return new Intl.NumberFormat('en-LK', {
    style: 'currency',
    currency: 'LKR',
    minimumFractionDigits: 2
  }).format(amount || 0);
}

// Format date for display
function formatDate(dateStr) {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
}

// Format month (YYYY-MM-01) to display
function formatMonth(monthStr) {
  if (!monthStr) return '-';
  const d = new Date(monthStr);
  return d.toLocaleDateString('en-GB', { month: 'long', year: 'numeric' });
}

// Get first day of month string
function getMonthStart(date) {
  const d = date ? new Date(date) : new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}

// Get previous month start
function getPreviousMonthStart(monthStr) {
  const d = new Date(monthStr || new Date());
  d.setMonth(d.getMonth() - 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}

// Get last day of month
function getMonthEnd(monthStr) {
  const d = new Date(monthStr);
  d.setMonth(d.getMonth() + 1);
  d.setDate(0);
  return d.toISOString().split('T')[0];
}

// Validate date is not in the future
function validateNotFuture(dateStr) {
  const input = new Date(dateStr);
  const today = new Date();
  today.setHours(23, 59, 59, 999);
  return input <= today;
}

// Check if date is within 6-month retention window
function isWithinRetention(dateStr) {
  const cutoff = new Date();
  cutoff.setMonth(cutoff.getMonth() - 6);
  cutoff.setDate(1);
  cutoff.setHours(0, 0, 0, 0);
  return new Date(dateStr) >= cutoff;
}

// Generate month options for selectors (last 6 months)
function generateMonthOptions() {
  const options = [];
  const now = new Date();
  for (let i = 0; i < 6; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
    const label = d.toLocaleDateString('en-GB', { month: 'long', year: 'numeric' });
    options.push({ value, label });
  }
  return options;
}

// Show/hide loading overlay
function showLoading() {
  const el = document.getElementById('loading-overlay');
  if (el) el.classList.remove('hidden');
}

function hideLoading() {
  const el = document.getElementById('loading-overlay');
  if (el) el.classList.add('hidden');
}

// Show alert message
function showAlert(message, type = 'info') {
  const container = document.getElementById('alert-container');
  if (!container) return;
  const div = document.createElement('div');
  div.className = `alert alert-${type}`;
  div.textContent = message;
  container.prepend(div);
  setTimeout(() => div.remove(), 5000);
}

// Confirm dialog
function confirmAction(message) {
  return window.confirm(message);
}

// Sanitize text input
function sanitize(str) {
  if (!str) return '';
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// Debounce function
function debounce(fn, delay = 300) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

// Mobile sidebar toggle
function initMobileSidebar() {
  const hamburger = document.querySelector('.hamburger');
  const sidebar = document.querySelector('.sidebar');
  const overlay = document.querySelector('.sidebar-overlay');

  if (hamburger && sidebar) {
    hamburger.addEventListener('click', () => {
      sidebar.classList.toggle('open');
      if (overlay) overlay.classList.toggle('active');
    });
  }

  if (overlay) {
    overlay.addEventListener('click', () => {
      sidebar.classList.remove('open');
      overlay.classList.remove('active');
    });
  }
}

// Set active nav link
function setActiveNav(page) {
  document.querySelectorAll('.sidebar-nav a').forEach(a => {
    if (a.getAttribute('href')?.includes(page)) {
      a.classList.add('active');
    }
  });
}

// Cleanup old data (6-month retention)
async function cleanupOldData() {
  const cutoff = new Date();
  cutoff.setMonth(cutoff.getMonth() - 6);
  const cutoffStr = cutoff.toISOString().split('T')[0];

  await supabase.from('projects').delete().lt('project_date', cutoffStr);
  await supabase.from('payouts').delete().lt('month', cutoffStr);
  await supabase.from('payout_calculations').delete().lt('month', cutoffStr);
  await supabase.from('company_fund').delete().lt('transaction_date', cutoffStr);
}
