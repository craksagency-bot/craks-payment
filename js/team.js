// CRAKS Payment Management System - Team Member Dashboard

async function initTeamDashboard() {
  const user = await requireAuth(['team']);
  if (!user) return;

  setupSidebarUser(user);
  setupLogout();
  initMobileSidebar();

  // Personal info
  document.getElementById('member-name').textContent = user.full_name;
  document.getElementById('member-join').textContent = formatDate(user.join_date);

  await loadTeamData(user.id);
}

async function loadTeamData(userId) {
  showLoading();

  // All-time total earnings
  const { data: allPayouts } = await supabase
    .from('payouts')
    .select('amount, status')
    .eq('user_id', userId)
    .eq('status', 'paid');

  let totalEarnings = 0;
  for (const p of (allPayouts || [])) {
    totalEarnings += parseFloat(p.amount) || 0;
  }
  document.getElementById('total-earnings').textContent = formatCurrency(totalEarnings);

  // Current month estimate
  const currentMonth = getMonthStart();
  const { data: currentPayout } = await supabase
    .from('payouts')
    .select('amount, status')
    .eq('user_id', userId)
    .eq('month', currentMonth)
    .single();

  if (currentPayout) {
    document.getElementById('current-estimate').textContent = formatCurrency(currentPayout.amount);
    document.getElementById('current-status').textContent = currentPayout.status;
    document.getElementById('current-status').className = `badge badge-${currentPayout.status}`;
  } else {
    document.getElementById('current-estimate').textContent = 'Not yet calculated';
    document.getElementById('current-status').textContent = 'pending';
    document.getElementById('current-status').className = 'badge badge-pending';
  }

  // Payment history (last 6 months)
  const cutoff = new Date();
  cutoff.setMonth(cutoff.getMonth() - 6);
  const cutoffStr = `${cutoff.getFullYear()}-${String(cutoff.getMonth() + 1).padStart(2, '0')}-01`;

  const { data: history } = await supabase
    .from('payouts')
    .select('month, amount, status, paid_date')
    .eq('user_id', userId)
    .gte('month', cutoffStr)
    .order('month', { ascending: false });

  const tbody = document.getElementById('history-table-body');
  tbody.innerHTML = '';

  for (const p of (history || [])) {
    tbody.innerHTML += `
      <tr>
        <td>${formatMonth(p.month)}</td>
        <td>${formatCurrency(p.amount)}</td>
        <td><span class="badge badge-${p.status}">${p.status}</span></td>
        <td>${p.paid_date ? formatDate(p.paid_date) : '-'}</td>
      </tr>`;
  }

  if (!history || history.length === 0) {
    tbody.innerHTML = '<tr><td colspan="4" class="text-center">No payment history yet</td></tr>';
  }

  hideLoading();
}

document.addEventListener('DOMContentLoaded', initTeamDashboard);
