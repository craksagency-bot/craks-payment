// CRAKS Payment Management System - Admin Dashboard

async function initAdminDashboard() {
  const user = await requireAuth(['admin']);
  if (!user) return;

  setupSidebarUser(user);
  setupLogout();
  initMobileSidebar();
  setActiveNav('admin-dashboard');

  await loadAdminStats();
  await loadRecentActivity();
}

async function loadAdminStats() {
  const currentMonth = getMonthStart();
  const monthEnd = getMonthEnd(currentMonth);

  // Total income this month
  const { data: projects } = await supabase
    .from('projects')
    .select('total_payment, net_profit')
    .gte('project_date', currentMonth)
    .lte('project_date', monthEnd);

  let totalIncome = 0;
  let totalProfit = 0;
  for (const p of (projects || [])) {
    totalIncome += parseFloat(p.total_payment) || 0;
    totalProfit += parseFloat(p.net_profit) || 0;
  }

  document.getElementById('stat-income').textContent = formatCurrency(totalIncome);
  document.getElementById('stat-projects').textContent = (projects || []).length;

  // Pending payouts
  const { data: pendingPayouts } = await supabase
    .from('payouts')
    .select('amount')
    .eq('status', 'pending');

  let pendingTotal = 0;
  for (const p of (pendingPayouts || [])) {
    pendingTotal += parseFloat(p.amount) || 0;
  }
  document.getElementById('stat-pending').textContent = formatCurrency(pendingTotal);

  // Company fund balance
  const { data: lastFund } = await supabase
    .from('company_fund')
    .select('balance')
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  const fundBalance = lastFund ? parseFloat(lastFund.balance) : 0;
  document.getElementById('stat-fund').textContent = formatCurrency(fundBalance);
}

async function loadRecentActivity() {
  const logEl = document.getElementById('activity-log');
  if (!logEl) return;

  // Recent projects
  const { data: recentProjects } = await supabase
    .from('projects')
    .select('client_name, project_name, created_at')
    .order('created_at', { ascending: false })
    .limit(5);

  // Recent payouts
  const { data: recentPayouts } = await supabase
    .from('payouts')
    .select('amount, status, updated_at, users(full_name)')
    .order('updated_at', { ascending: false })
    .limit(5);

  const activities = [];

  for (const p of (recentProjects || [])) {
    activities.push({
      text: `Project added: ${sanitize(p.client_name)} - ${sanitize(p.project_name || 'Untitled')}`,
      time: p.created_at
    });
  }

  for (const p of (recentPayouts || [])) {
    const name = p.users?.full_name || 'Unknown';
    activities.push({
      text: `Payout ${p.status}: ${sanitize(name)} - ${formatCurrency(p.amount)}`,
      time: p.updated_at
    });
  }

  activities.sort((a, b) => new Date(b.time) - new Date(a.time));

  logEl.innerHTML = '';
  for (const act of activities.slice(0, 10)) {
    logEl.innerHTML += `
      <li>
        <span class="activity-dot"></span>
        <div>
          <div>${act.text}</div>
          <div class="activity-time">${formatDate(act.time)}</div>
        </div>
      </li>`;
  }

  if (activities.length === 0) {
    logEl.innerHTML = '<li class="empty-state"><p>No recent activity</p></li>';
  }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', initAdminDashboard);
