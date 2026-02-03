// CRAKS Payment Management System - User Management

async function initUsersPage() {
  const user = await requireAuth(['admin']);
  if (!user) return;

  setupSidebarUser(user);
  setupLogout();
  initMobileSidebar();
  setActiveNav('manage-users');

  document.getElementById('user-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    await addUser();
  });

  await loadUsers();
}

async function loadUsers() {
  showLoading();

  const { data: users, error } = await supabase
    .from('users')
    .select('*')
    .order('role')
    .order('full_name');

  const tbody = document.getElementById('users-table-body');
  tbody.innerHTML = '';

  for (const u of (users || [])) {
    tbody.innerHTML += `
      <tr>
        <td>${sanitize(u.full_name)}</td>
        <td>${sanitize(u.email)}</td>
        <td><span class="badge badge-${u.role === 'admin' ? 'active' : u.role === 'advisor' ? 'open' : 'pending'}">${u.role}</span></td>
        <td><span class="badge badge-${u.active ? 'active' : 'inactive'}">${u.active ? 'Active' : 'Inactive'}</span></td>
        <td>${formatDate(u.join_date)}</td>
        <td>${sanitize(u.phone || '-')}</td>
        <td>
          <button class="btn btn-sm btn-outline" onclick="toggleUserStatus('${u.id}', ${u.active})">
            ${u.active ? 'Deactivate' : 'Activate'}
          </button>
        </td>
      </tr>`;
  }

  if (!users || users.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="text-center">No users found</td></tr>';
  }

  hideLoading();
}

async function addUser() {
  const email = document.getElementById('new-email').value.trim();
  const fullName = document.getElementById('new-name').value.trim();
  const phone = document.getElementById('new-phone').value.trim();
  const bankDetails = document.getElementById('new-bank').value.trim();
  const role = document.getElementById('new-role').value;
  const password = document.getElementById('new-password').value;

  if (!email || !fullName || !role || !password) {
    showAlert('Please fill all required fields', 'danger');
    return;
  }

  if (password.length < 8) {
    showAlert('Password must be at least 8 characters', 'danger');
    return;
  }

  showLoading();

  try {
    // Create auth user via Supabase Auth
    // Note: In production, use a Supabase Edge Function with service_role key
    // For now, admin creates user and they get an invite email
    const { data: authData, error: authErr } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    });

    // If admin API not available, use signUp (user will need to verify email)
    let userId;
    if (authErr) {
      // Fallback: use regular signup
      const { data: signUpData, error: signUpErr } = await supabase.auth.signUp({
        email,
        password
      });
      if (signUpErr) throw signUpErr;
      userId = signUpData.user.id;
    } else {
      userId = authData.user.id;
    }

    // Create user record in users table
    const { error: insertErr } = await supabase.from('users').insert({
      id: userId,
      email,
      full_name: fullName,
      phone: phone || null,
      bank_details: bankDetails || null,
      role
    });

    if (insertErr) throw insertErr;

    showAlert(`User ${fullName} created successfully`, 'success');
    document.getElementById('user-form').reset();
    await loadUsers();
  } catch (err) {
    showAlert('Error creating user: ' + err.message, 'danger');
  }

  hideLoading();
}

async function toggleUserStatus(userId, isActive) {
  const action = isActive ? 'deactivate' : 'activate';
  if (!confirmAction(`Are you sure you want to ${action} this user?`)) return;

  showLoading();

  const updates = { active: !isActive };
  if (isActive) {
    updates.leave_date = new Date().toISOString().split('T')[0];
  } else {
    updates.leave_date = null;
  }

  const { error } = await supabase
    .from('users')
    .update(updates)
    .eq('id', userId);

  if (error) {
    showAlert('Error: ' + error.message, 'danger');
  } else {
    showAlert(`User ${action}d successfully`, 'success');
    await loadUsers();
  }

  hideLoading();
}

document.addEventListener('DOMContentLoaded', initUsersPage);
