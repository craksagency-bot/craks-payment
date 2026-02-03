// CRAKS Payment Management System - Company Fund

let currentUserRole = null;

async function initCompanyFundPage() {
  const user = await requireAuth(['admin', 'advisor']);
  if (!user) return;

  currentUserRole = user.role;
  setupSidebarUser(user);
  setupLogout();
  initMobileSidebar();
  setActiveNav('company-fund');

  // Hide form for advisor
  if (user.role === 'advisor') {
    const form = document.getElementById('fund-form');
    if (form) form.classList.add('hidden');
  }

  if (user.role === 'admin') {
    document.getElementById('fund-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      await addTransaction(user.id);
    });
  }

  await loadFundData();
}

async function loadFundData() {
  showLoading();

  // Get current balance
  const { data: lastEntry } = await supabase
    .from('company_fund')
    .select('balance')
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  const balance = lastEntry ? parseFloat(lastEntry.balance) : 0;
  document.getElementById('fund-balance').textContent = formatCurrency(balance);

  // Get transaction history
  const { data: transactions } = await supabase
    .from('company_fund')
    .select('*, users:created_by(full_name)')
    .order('created_at', { ascending: false })
    .limit(50);

  const tbody = document.getElementById('fund-table-body');
  tbody.innerHTML = '';

  for (const t of (transactions || [])) {
    const typeClass = t.transaction_type === 'credit' ? 'positive' : 'negative';
    const sign = t.transaction_type === 'credit' ? '+' : '-';
    tbody.innerHTML += `
      <tr>
        <td>${formatDate(t.transaction_date)}</td>
        <td><span class="badge badge-${t.transaction_type === 'credit' ? 'paid' : 'pending'}">${t.transaction_type}</span></td>
        <td class="${typeClass}">${sign}${formatCurrency(t.amount)}</td>
        <td>${formatCurrency(t.balance)}</td>
        <td>${sanitize(t.description)}</td>
        <td>${t.users?.full_name || '-'}</td>
      </tr>`;
  }

  if (!transactions || transactions.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" class="text-center">No transactions yet</td></tr>';
  }

  hideLoading();
}

async function addTransaction(userId) {
  const type = document.getElementById('txn-type').value;
  const amount = parseFloat(document.getElementById('txn-amount').value);
  const description = document.getElementById('txn-description').value.trim();
  const date = document.getElementById('txn-date').value;

  if (!type || !amount || !description || !date) {
    showAlert('Please fill all fields', 'danger');
    return;
  }

  showLoading();

  // Get current balance
  const { data: lastEntry } = await supabase
    .from('company_fund')
    .select('balance')
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  const currentBalance = lastEntry ? parseFloat(lastEntry.balance) : 0;
  const newBalance = type === 'credit'
    ? currentBalance + amount
    : currentBalance - amount;

  const { error } = await supabase.from('company_fund').insert({
    transaction_type: type,
    amount,
    balance: newBalance,
    description,
    transaction_date: date,
    created_by: userId
  });

  if (error) {
    showAlert('Error: ' + error.message, 'danger');
  } else {
    showAlert('Transaction added', 'success');
    document.getElementById('fund-form').reset();
    await loadFundData();
  }

  hideLoading();
}

document.addEventListener('DOMContentLoaded', initCompanyFundPage);
