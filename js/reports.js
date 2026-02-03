// CRAKS Payment Management System - Reports & Export

async function initReportsPage() {
  const user = await requireAuth(['admin', 'advisor']);
  if (!user) return;

  setupSidebarUser(user);
  setupLogout();
  initMobileSidebar();
  setActiveNav('reports');

  document.getElementById('btn-preview').addEventListener('click', loadReport);
  document.getElementById('btn-export-csv').addEventListener('click', exportCSV);
  document.getElementById('btn-export-pdf').addEventListener('click', exportPDF);

  // Set default dates
  const now = new Date();
  const sixMonthsAgo = new Date();
  sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
  document.getElementById('date-from').value = sixMonthsAgo.toISOString().split('T')[0];
  document.getElementById('date-to').value = now.toISOString().split('T')[0];
}

let reportData = [];

async function loadReport() {
  const reportType = document.getElementById('report-type').value;
  const dateFrom = document.getElementById('date-from').value;
  const dateTo = document.getElementById('date-to').value;

  if (!dateFrom || !dateTo) {
    showAlert('Please select date range', 'danger');
    return;
  }

  showLoading();

  const previewEl = document.getElementById('report-preview');
  reportData = [];

  switch (reportType) {
    case 'income':
      await loadIncomeReport(dateFrom, dateTo, previewEl);
      break;
    case 'payouts':
      await loadPayoutsReport(dateFrom, dateTo, previewEl);
      break;
    case 'yearly':
      await loadYearlySummary(dateFrom, dateTo, previewEl);
      break;
    case 'fund':
      await loadFundStatement(dateFrom, dateTo, previewEl);
      break;
  }

  hideLoading();
}

async function loadIncomeReport(from, to, el) {
  const { data: projects } = await supabase
    .from('projects')
    .select('*')
    .gte('project_date', from)
    .lte('project_date', to)
    .order('project_date', { ascending: false });

  reportData = (projects || []).map(p => ({
    Date: p.project_date,
    Client: p.client_name,
    Project: p.project_name || '-',
    Payment: p.total_payment,
    Expenses: p.total_expenses,
    'Net Profit': p.net_profit,
    Status: p.status
  }));

  let totalPayment = 0, totalExpenses = 0, totalProfit = 0;
  let html = `<table><thead><tr>
    <th>Date</th><th>Client</th><th>Project</th><th>Payment</th><th>Expenses</th><th>Net Profit</th><th>Status</th>
  </tr></thead><tbody>`;

  for (const p of (projects || [])) {
    totalPayment += parseFloat(p.total_payment);
    totalExpenses += parseFloat(p.total_expenses);
    totalProfit += parseFloat(p.net_profit);
    html += `<tr>
      <td>${formatDate(p.project_date)}</td>
      <td>${sanitize(p.client_name)}</td>
      <td>${sanitize(p.project_name || '-')}</td>
      <td>${formatCurrency(p.total_payment)}</td>
      <td>${formatCurrency(p.total_expenses)}</td>
      <td>${formatCurrency(p.net_profit)}</td>
      <td><span class="badge badge-${p.status}">${p.status}</span></td>
    </tr>`;
  }

  html += `</tbody><tfoot><tr>
    <td colspan="3"><strong>Total</strong></td>
    <td><strong>${formatCurrency(totalPayment)}</strong></td>
    <td><strong>${formatCurrency(totalExpenses)}</strong></td>
    <td><strong>${formatCurrency(totalProfit)}</strong></td>
    <td></td>
  </tr></tfoot></table>`;

  el.innerHTML = html;
}

async function loadPayoutsReport(from, to, el) {
  const fromMonth = getMonthStart(new Date(from));
  const toMonth = getMonthStart(new Date(to));

  const { data: payouts } = await supabase
    .from('payouts')
    .select('*, users(full_name, role)')
    .gte('month', fromMonth)
    .lte('month', toMonth)
    .order('month', { ascending: false });

  reportData = (payouts || []).map(p => ({
    Month: p.month,
    Name: p.users?.full_name || '-',
    Role: p.users?.role || '-',
    Amount: p.amount,
    Status: p.status,
    'Paid Date': p.paid_date || '-'
  }));

  let html = `<table><thead><tr>
    <th>Month</th><th>Name</th><th>Role</th><th>Amount</th><th>Status</th><th>Paid Date</th>
  </tr></thead><tbody>`;

  for (const p of (payouts || [])) {
    html += `<tr>
      <td>${formatMonth(p.month)}</td>
      <td>${sanitize(p.users?.full_name || '-')}</td>
      <td>${p.users?.role || '-'}</td>
      <td>${formatCurrency(p.amount)}</td>
      <td><span class="badge badge-${p.status}">${p.status}</span></td>
      <td>${p.paid_date ? formatDate(p.paid_date) : '-'}</td>
    </tr>`;
  }

  html += '</tbody></table>';
  el.innerHTML = html;
}

async function loadYearlySummary(from, to, el) {
  const fromMonth = getMonthStart(new Date(from));
  const toMonth = getMonthStart(new Date(to));

  const { data: calcs } = await supabase
    .from('payout_calculations')
    .select('*')
    .gte('month', fromMonth)
    .lte('month', toMonth)
    .order('month', { ascending: false });

  reportData = (calcs || []).map(c => ({
    Month: c.month,
    'Net Profit': c.total_net_profit,
    'Founder (30%)': c.founder_amount,
    'Advisor (15%)': c.advisor_amount,
    'Company Fund (15%)': c.company_fund_amount,
    'Team Pool (40%)': c.team_pool_amount,
    'Team Count': c.active_team_count,
    'Per Member': c.per_member_amount
  }));

  let html = `<table><thead><tr>
    <th>Month</th><th>Net Profit</th><th>Founder 30%</th><th>Advisor 15%</th><th>Fund 15%</th><th>Team Pool 40%</th><th>Members</th><th>Per Member</th>
  </tr></thead><tbody>`;

  for (const c of (calcs || [])) {
    html += `<tr>
      <td>${formatMonth(c.month)}</td>
      <td>${formatCurrency(c.total_net_profit)}</td>
      <td>${formatCurrency(c.founder_amount)}</td>
      <td>${formatCurrency(c.advisor_amount)}</td>
      <td>${formatCurrency(c.company_fund_amount)}</td>
      <td>${formatCurrency(c.team_pool_amount)}</td>
      <td>${c.active_team_count}</td>
      <td>${formatCurrency(c.per_member_amount)}</td>
    </tr>`;
  }

  html += '</tbody></table>';
  el.innerHTML = html;
}

async function loadFundStatement(from, to, el) {
  const { data: transactions } = await supabase
    .from('company_fund')
    .select('*')
    .gte('transaction_date', from)
    .lte('transaction_date', to)
    .order('created_at', { ascending: false });

  reportData = (transactions || []).map(t => ({
    Date: t.transaction_date,
    Type: t.transaction_type,
    Amount: t.amount,
    Balance: t.balance,
    Description: t.description
  }));

  let html = `<table><thead><tr>
    <th>Date</th><th>Type</th><th>Amount</th><th>Balance</th><th>Description</th>
  </tr></thead><tbody>`;

  for (const t of (transactions || [])) {
    html += `<tr>
      <td>${formatDate(t.transaction_date)}</td>
      <td><span class="badge badge-${t.transaction_type === 'credit' ? 'paid' : 'pending'}">${t.transaction_type}</span></td>
      <td>${formatCurrency(t.amount)}</td>
      <td>${formatCurrency(t.balance)}</td>
      <td>${sanitize(t.description)}</td>
    </tr>`;
  }

  html += '</tbody></table>';
  el.innerHTML = html;
}

function exportCSV() {
  if (reportData.length === 0) {
    showAlert('No data to export. Preview a report first.', 'warning');
    return;
  }

  const headers = Object.keys(reportData[0]);
  let csv = headers.join(',') + '\n';
  for (const row of reportData) {
    csv += headers.map(h => {
      const val = String(row[h] || '');
      return val.includes(',') ? `"${val}"` : val;
    }).join(',') + '\n';
  }

  const blob = new Blob([csv], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `craks-report-${new Date().toISOString().split('T')[0]}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

function exportPDF() {
  // Use browser print dialog for PDF
  if (reportData.length === 0) {
    showAlert('No data to export. Preview a report first.', 'warning');
    return;
  }

  const printWindow = window.open('', '_blank');
  const preview = document.getElementById('report-preview').innerHTML;
  printWindow.document.write(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>CRAKS Report</title>
      <style>
        body { font-family: Arial, sans-serif; font-size: 12px; padding: 20px; }
        h1 { font-size: 18px; margin-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
        th { background: #f3f4f6; font-weight: bold; }
        .badge { padding: 2px 6px; border-radius: 4px; font-size: 11px; }
      </style>
    </head>
    <body>
      <h1>CRAKS Payment Report</h1>
      <p>Generated: ${new Date().toLocaleDateString()}</p>
      ${preview}
    </body>
    </html>
  `);
  printWindow.document.close();
  printWindow.print();
}

document.addEventListener('DOMContentLoaded', initReportsPage);
