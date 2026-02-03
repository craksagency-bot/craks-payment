// CRAKS Payment Management System - Projects Management

let currentProjectId = null;
let installmentCount = 0;
let expenseCount = 0;

async function initProjectPage() {
  const user = await requireAuth(['admin']);
  if (!user) return;

  setupSidebarUser(user);
  setupLogout();
  initMobileSidebar();
  setActiveNav('add-project');

  // Check if editing existing project
  const params = new URLSearchParams(window.location.search);
  currentProjectId = params.get('id');

  if (currentProjectId) {
    document.getElementById('page-title').textContent = 'Edit Project';
    await loadProject(currentProjectId);
  }

  setupProjectForm();
}

function setupProjectForm() {
  // Add installment button
  document.getElementById('btn-add-installment').addEventListener('click', () => {
    addInstallmentRow();
  });

  // Add expense button
  document.getElementById('btn-add-expense').addEventListener('click', () => {
    addExpenseRow();
  });

  // Form submission
  document.getElementById('project-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    await saveProject();
  });

  // Payment input change - update calculations
  document.getElementById('total-payment-input').addEventListener('input', updateCalculations);

  // Add initial rows
  if (!currentProjectId) {
    addInstallmentRow();
  }
}

function addInstallmentRow(data = {}) {
  installmentCount++;
  const container = document.getElementById('installments-list');
  const div = document.createElement('div');
  div.className = 'dynamic-item installment-item';
  div.dataset.index = installmentCount;
  div.innerHTML = `
    <span class="item-number">#${installmentCount}</span>
    <div class="form-group">
      <label>Amount <span class="required">*</span></label>
      <input type="number" step="0.01" min="0" class="inst-amount" value="${data.amount || ''}" required placeholder="0.00">
    </div>
    <div class="form-group">
      <label>Payment Date <span class="required">*</span></label>
      <input type="date" class="inst-date" value="${data.payment_date || ''}" required>
    </div>
    <div class="form-group">
      <label>Notes</label>
      <input type="text" class="inst-notes" value="${sanitize(data.notes || '')}" placeholder="Optional notes">
    </div>
    <button type="button" class="btn-remove" onclick="removeRow(this)">&times;</button>
  `;
  container.appendChild(div);

  // Update total when amount changes
  div.querySelector('.inst-amount').addEventListener('input', updateInstallmentTotal);
}

function addExpenseRow(data = {}) {
  expenseCount++;
  const container = document.getElementById('expenses-list');
  const div = document.createElement('div');
  div.className = 'dynamic-item expense-item';
  div.dataset.index = expenseCount;
  div.innerHTML = `
    <div class="form-group">
      <label>Category <span class="required">*</span></label>
      <select class="exp-category" required>
        <option value="">Select...</option>
        <option value="equipment" ${data.category === 'equipment' ? 'selected' : ''}>Equipment</option>
        <option value="transport" ${data.category === 'transport' ? 'selected' : ''}>Transport</option>
        <option value="freelancer" ${data.category === 'freelancer' ? 'selected' : ''}>Freelancer</option>
        <option value="software" ${data.category === 'software' ? 'selected' : ''}>Software</option>
        <option value="props" ${data.category === 'props' ? 'selected' : ''}>Props</option>
        <option value="ads" ${data.category === 'ads' ? 'selected' : ''}>Ads</option>
        <option value="marketing" ${data.category === 'marketing' ? 'selected' : ''}>Marketing</option>
        <option value="other" ${data.category === 'other' ? 'selected' : ''}>Other</option>
      </select>
    </div>
    <div class="form-group">
      <label>Amount <span class="required">*</span></label>
      <input type="number" step="0.01" min="0" class="exp-amount" value="${data.amount || ''}" required placeholder="0.00">
    </div>
    <div class="form-group">
      <label>Date <span class="required">*</span></label>
      <input type="date" class="exp-date" value="${data.expense_date || ''}" required>
    </div>
    <div class="form-group">
      <label>Description</label>
      <input type="text" class="exp-description" value="${sanitize(data.description || '')}" placeholder="Description">
    </div>
    <button type="button" class="btn-remove" onclick="removeRow(this)">&times;</button>
  `;
  container.appendChild(div);

  div.querySelector('.exp-amount').addEventListener('input', updateCalculations);
}

function removeRow(btn) {
  btn.closest('.dynamic-item').remove();
  updateInstallmentTotal();
  updateCalculations();
}

function updateInstallmentTotal() {
  let total = 0;
  document.querySelectorAll('.inst-amount').forEach(input => {
    total += parseFloat(input.value) || 0;
  });
  document.getElementById('total-payment-input').value = total.toFixed(2);
  updateCalculations();
}

function updateCalculations() {
  const totalPayment = parseFloat(document.getElementById('total-payment-input').value) || 0;

  let totalExpenses = 0;
  document.querySelectorAll('.exp-amount').forEach(input => {
    totalExpenses += parseFloat(input.value) || 0;
  });

  const netProfit = totalPayment - totalExpenses;

  document.getElementById('total-expenses-display').textContent = formatCurrency(totalExpenses);
  const netEl = document.getElementById('net-profit-display');
  netEl.textContent = formatCurrency(netProfit);
  netEl.className = 'calc-value' + (netProfit < 0 ? ' negative' : '');
}

async function loadProject(id) {
  showLoading();

  const { data: project, error } = await supabase
    .from('projects')
    .select('*')
    .eq('id', id)
    .single();

  if (error || !project) {
    hideLoading();
    showAlert('Project not found', 'danger');
    return;
  }

  document.getElementById('client-name').value = project.client_name;
  document.getElementById('project-name').value = project.project_name || '';
  document.getElementById('project-date').value = project.project_date;
  document.getElementById('total-payment-input').value = project.total_payment;
  document.getElementById('project-status').value = project.status;

  // Load installments
  const { data: installments } = await supabase
    .from('project_installments')
    .select('*')
    .eq('project_id', id)
    .order('installment_number');

  for (const inst of (installments || [])) {
    addInstallmentRow(inst);
  }

  // Load expenses
  const { data: expenses } = await supabase
    .from('expenses')
    .select('*')
    .eq('project_id', id)
    .order('expense_date');

  for (const exp of (expenses || [])) {
    addExpenseRow(exp);
  }

  updateCalculations();
  hideLoading();
}

async function saveProject() {
  const clientName = document.getElementById('client-name').value.trim();
  const projectName = document.getElementById('project-name').value.trim();
  const projectDate = document.getElementById('project-date').value;
  const totalPayment = parseFloat(document.getElementById('total-payment-input').value) || 0;
  const status = document.getElementById('project-status')?.value || 'open';

  // Validation
  if (!clientName) { showAlert('Client name is required', 'danger'); return; }
  if (!projectDate) { showAlert('Project date is required', 'danger'); return; }
  if (!validateNotFuture(projectDate)) { showAlert('Project date cannot be in the future', 'danger'); return; }

  // Collect expenses
  let totalExpenses = 0;
  const expenseRows = document.querySelectorAll('.expense-item');
  const expenses = [];
  for (const row of expenseRows) {
    const cat = row.querySelector('.exp-category').value;
    const amt = parseFloat(row.querySelector('.exp-amount').value) || 0;
    const dt = row.querySelector('.exp-date').value;
    const desc = row.querySelector('.exp-description').value;
    if (!cat || !dt) { showAlert('All expense fields must be filled', 'danger'); return; }
    expenses.push({ category: cat, amount: amt, expense_date: dt, description: desc });
    totalExpenses += amt;
  }

  // Collect installments
  const instRows = document.querySelectorAll('.installment-item');
  const installments = [];
  let instNum = 0;
  for (const row of instRows) {
    instNum++;
    const amt = parseFloat(row.querySelector('.inst-amount').value) || 0;
    const dt = row.querySelector('.inst-date').value;
    const notes = row.querySelector('.inst-notes').value;
    if (!dt) { showAlert('All installment dates must be filled', 'danger'); return; }
    installments.push({ installment_number: instNum, amount: amt, payment_date: dt, notes });
  }

  showLoading();

  try {
    const user = await getCurrentUser();

    if (currentProjectId) {
      // Check if payout already paid for this project's month
      // Update project
      const { error } = await supabase
        .from('projects')
        .update({
          client_name: clientName,
          project_name: projectName,
          project_date: projectDate,
          total_payment: totalPayment,
          total_expenses: totalExpenses,
          status
        })
        .eq('id', currentProjectId);

      if (error) throw error;

      // Delete and re-insert installments
      await supabase.from('project_installments').delete().eq('project_id', currentProjectId);
      if (installments.length > 0) {
        await supabase.from('project_installments').insert(
          installments.map(i => ({ ...i, project_id: currentProjectId }))
        );
      }

      // Delete and re-insert expenses
      await supabase.from('expenses').delete().eq('project_id', currentProjectId);
      if (expenses.length > 0) {
        await supabase.from('expenses').insert(
          expenses.map(e => ({ ...e, project_id: currentProjectId, created_by: user.id }))
        );
      }

      showAlert('Project updated successfully', 'success');
    } else {
      // Create new project
      const { data: newProject, error } = await supabase
        .from('projects')
        .insert({
          client_name: clientName,
          project_name: projectName,
          project_date: projectDate,
          total_payment: totalPayment,
          total_expenses: totalExpenses,
          status,
          created_by: user.id
        })
        .select()
        .single();

      if (error) throw error;

      // Insert installments
      if (installments.length > 0) {
        await supabase.from('project_installments').insert(
          installments.map(i => ({ ...i, project_id: newProject.id }))
        );
      }

      // Insert expenses
      if (expenses.length > 0) {
        await supabase.from('expenses').insert(
          expenses.map(e => ({ ...e, project_id: newProject.id, created_by: user.id }))
        );
      }

      showAlert('Project created successfully', 'success');
      setTimeout(() => {
        window.location.href = '/pages/admin-dashboard.html';
      }, 1500);
    }
  } catch (err) {
    showAlert('Error saving project: ' + err.message, 'danger');
  }

  hideLoading();
}

// Delete project
async function deleteProject(id) {
  if (!confirmAction('Are you sure you want to delete this project? This cannot be undone.')) return;

  showLoading();
  const { error } = await supabase.from('projects').delete().eq('id', id);
  hideLoading();

  if (error) {
    showAlert('Error deleting project: ' + error.message, 'danger');
  } else {
    showAlert('Project deleted', 'success');
    setTimeout(() => window.location.reload(), 1000);
  }
}

document.addEventListener('DOMContentLoaded', initProjectPage);
