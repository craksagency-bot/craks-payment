// CRAKS Payment Management System - Payouts Management

async function initPayoutsPage() {
  const user = await requireAuth(['admin']);
  if (!user) return;

  setupSidebarUser(user);
  setupLogout();
  initMobileSidebar();
  setActiveNav('monthly-payout');

  // Populate month selector
  const monthSelect = document.getElementById('month-select');
  const options = generateMonthOptions();
  for (const opt of options) {
    const el = document.createElement('option');
    el.value = opt.value;
    el.textContent = opt.label;
    monthSelect.appendChild(el);
  }

  // Generate payouts button
  document.getElementById('btn-generate').addEventListener('click', async () => {
    await handleGeneratePayouts(user.id);
  });

  // Load initial month data
  monthSelect.addEventListener('change', () => loadMonthData(monthSelect.value));
  loadMonthData(monthSelect.value);
}

async function loadMonthData(month) {
  showLoading();

  // Check if calculation exists
  const { data: calc } = await supabase
    .from('payout_calculations')
    .select('*')
    .eq('month', month)
    .single();

  const summaryEl = document.getElementById('calc-summary');
  const payoutsEl = document.getElementById('payouts-table-body');
  const generateBtn = document.getElementById('btn-generate');

  if (calc) {
    generateBtn.disabled = true;
    generateBtn.textContent = 'Already Generated';

    summaryEl.classList.remove('hidden');
    document.getElementById('summary-profit').textContent = formatCurrency(calc.total_net_profit);
    document.getElementById('summary-founder').textContent = formatCurrency(calc.founder_amount);
    document.getElementById('summary-advisor').textContent = formatCurrency(calc.advisor_amount);
    document.getElementById('summary-fund').textContent = formatCurrency(calc.company_fund_amount);
    document.getElementById('summary-team-pool').textContent = formatCurrency(calc.team_pool_amount);
    document.getElementById('summary-team-count').textContent = calc.active_team_count;
    document.getElementById('summary-per-member').textContent = formatCurrency(calc.per_member_amount);

    // Load payouts for this month
    const { data: payouts } = await supabase
      .from('payouts')
      .select('*, users(full_name, role)')
      .eq('month', month)
      .order('amount', { ascending: false });

    payoutsEl.innerHTML = '';
    for (const p of (payouts || [])) {
      const name = p.users?.full_name || 'Unknown';
      const role = p.users?.role || '';
      payoutsEl.innerHTML += `
        <tr>
          <td>${sanitize(name)}</td>
          <td><span class="badge badge-${role === 'admin' ? 'active' : role === 'advisor' ? 'open' : 'pending'}">${role}</span></td>
          <td>${formatCurrency(p.amount)}</td>
          <td><span class="badge badge-${p.status}">${p.status}</span></td>
          <td>${p.paid_date ? formatDate(p.paid_date) : '-'}</td>
          <td>
            ${p.status === 'pending' ? `<button class="btn btn-sm btn-success" onclick="markAsPaid('${p.id}')">Mark Paid</button>` : ''}
          </td>
        </tr>`;
    }

    if (!payouts || payouts.length === 0) {
      payoutsEl.innerHTML = '<tr><td colspan="6" class="text-center">No payouts found</td></tr>';
    }
  } else {
    generateBtn.disabled = false;
    generateBtn.textContent = 'Generate Payouts';
    summaryEl.classList.add('hidden');
    payoutsEl.innerHTML = '<tr><td colspan="6" class="text-center">No payouts generated for this month yet</td></tr>';
  }

  hideLoading();
}

async function handleGeneratePayouts(adminId) {
  const month = document.getElementById('month-select').value;

  if (!confirmAction(`Generate payouts for ${formatMonth(month)}? This will calculate distributions for the previous month's projects.`)) {
    return;
  }

  showLoading();
  try {
    const result = await generateMonthlyPayouts(month, adminId);
    showAlert(`Payouts generated! Net profit: ${formatCurrency(result.totalNetProfit)}, ${result.payoutsCreated} payouts created.`, 'success');
    await loadMonthData(month);
  } catch (err) {
    showAlert('Error: ' + err.message, 'danger');
  }
  hideLoading();
}

async function markAsPaid(payoutId) {
  if (!confirmAction('Mark this payout as paid?')) return;

  showLoading();
  const user = await getCurrentUser();

  const { error } = await supabase
    .from('payouts')
    .update({
      status: 'paid',
      paid_by: user.id,
      paid_date: new Date().toISOString().split('T')[0]
    })
    .eq('id', payoutId);

  if (error) {
    showAlert('Error: ' + error.message, 'danger');
  } else {
    showAlert('Payout marked as paid', 'success');
    const month = document.getElementById('month-select').value;
    await loadMonthData(month);
  }
  hideLoading();
}

document.addEventListener('DOMContentLoaded', initPayoutsPage);
