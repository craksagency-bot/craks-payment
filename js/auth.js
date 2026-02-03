// CRAKS Payment Management System - Authentication

const INACTIVITY_TIMEOUT = 30 * 60 * 1000; // 30 minutes
let inactivityTimer;

// Reset inactivity timer on user activity
function resetInactivityTimer() {
  clearTimeout(inactivityTimer);
  inactivityTimer = setTimeout(async () => {
    alert('Session expired due to inactivity. Please log in again.');
    await logout();
  }, INACTIVITY_TIMEOUT);
}

// Initialize activity listeners
function initActivityTracking() {
  ['mousemove', 'keydown', 'click', 'scroll'].forEach(event => {
    document.addEventListener(event, resetInactivityTimer);
  });
  resetInactivityTimer();
}

// Login
async function login(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

// Logout
async function logout() {
  clearTimeout(inactivityTimer);
  await supabase.auth.signOut();
  window.location.href = '/pages/login.html';
}

// Get current session user + role
async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: userData, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', user.id)
    .single();

  if (error || !userData) return null;
  if (!userData.active) {
    alert('Your account is inactive.');
    await logout();
    return null;
  }

  return userData;
}

// Require authentication - redirect if not logged in
async function requireAuth(allowedRoles) {
  const user = await getCurrentUser();
  if (!user) {
    window.location.href = '/pages/login.html';
    return null;
  }

  if (allowedRoles && !allowedRoles.includes(user.role)) {
    // Redirect to appropriate dashboard
    redirectToDashboard(user.role);
    return null;
  }

  initActivityTracking();
  return user;
}

// Redirect user to their dashboard based on role
function redirectToDashboard(role) {
  switch (role) {
    case 'admin':
      window.location.href = '/pages/admin-dashboard.html';
      break;
    case 'advisor':
      window.location.href = '/pages/advisor-dashboard.html';
      break;
    case 'team':
      window.location.href = '/pages/team-dashboard.html';
      break;
    default:
      window.location.href = '/pages/login.html';
  }
}

// Send password reset email
async function resetPassword(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin + '/pages/login.html'
  });
  if (error) throw error;
}

// Setup sidebar user info
function setupSidebarUser(user) {
  const nameEl = document.querySelector('.user-name');
  const roleEl = document.querySelector('.user-role');
  if (nameEl) nameEl.textContent = user.full_name;
  if (roleEl) roleEl.textContent = user.role;
}

// Setup logout button
function setupLogout() {
  const logoutBtn = document.getElementById('btn-logout');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', async (e) => {
      e.preventDefault();
      await logout();
    });
  }
}
