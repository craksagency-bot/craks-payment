// CRAKS Payment Management System - Advisor Dashboard

async function initAdvisorDashboard() {
  const user = await requireAuth(['advisor']);
  if (!user) return;

  setupSidebarUser(user);
  setupLogout();
  initMobileSidebar();
  setActiveNav('advisor-dashboard');

  await loadAdvisorData();
}

async function loadAdvisorData() {
  showLoading();
  const currentMonth = getMonthStart();
  const monthEnd = getMonthEnd(currentMonth);

  // Stats
  const { data: projects } = await supabase
    .from('projects')
    .select('total_payment, net_profit')
    .gte('project_date', currentMonth)
    .lte('project_date', monthEnd);

  let totalIncome = 0, totalProfit = 0;
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

  // Fund balance
  const { data: lastFund } = await supabase
    .from('company_fund')
    .select('balance')
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  document.getElementById('stat-fund').textContent = formatCurrency(lastFund?.balance || 0);

  // All projects list
  const { data: allProjects } = await supabase
    .from('projects')
    .select('*')
    .order('project_date', { ascending: false })
    .limit(20);

  const tbody = document.getElementById('projects-table-body');
  tbody.innerHTML = '';
  for (const p of (allProjects || [])) {
    tbody.innerHTML += `
      <tr>
        <td>${formatDate(p.project_date)}</td>
        <td>${sanitize(p.client_name)}</td>
        <td>${sanitize(p.project_name || '-')}</td>
        <td>${formatCurrency(p.total_payment)}</td>
        <td>${formatCurrency(p.total_expenses)}</td>
        <td>${formatCurrency(p.net_profit)}</td>
        <td><span class="badge badge-${p.status}">${p.status}</span></td>
      </tr>`;
  }

  // Recent payouts
  const { data: recentPayouts } = await supabase
    .from('payouts')
    .select('*, users(full_name)')
    .order('created_at', { ascending: false })
    .limit(10);

  const payoutsBody = document.getElementById('payouts-table-body');
  if (payoutsBody) {
    payoutsBody.innerHTML = '';
    for (const p of (recentPayouts || [])) {
      payoutsBody.innerHTML += `
        <tr>
          <td>${formatMonth(p.month)}</td>
          <td>${sanitize(p.users?.full_name || '-')}</td>
          <td>${formatCurrency(p.amount)}</td>
          <td><span class="badge badge-${p.status}">${p.status}</span></td>
        </tr>`;
    }
  }

  hideLoading();
}

document.addEventListener('DOMContentLoaded', initAdvisorDashboard);
