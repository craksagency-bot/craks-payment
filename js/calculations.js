// CRAKS Payment Management System - Calculation Logic

// Fixed distribution percentages (UNMODIFIABLE)
const DISTRIBUTION = Object.freeze({
  FOUNDER: 0.30,
  ADVISOR: 0.15,
  COMPANY_FUND: 0.15,
  TEAM_POOL: 0.40
});

// Calculate net profit
function calculateNetProfit(totalPayment, totalExpenses) {
  return totalPayment - totalExpenses;
}

// Calculate distribution from net profit
function calculateDistribution(netProfit) {
  if (netProfit <= 0) {
    return { founder: 0, advisor: 0, companyFund: 0, teamPool: 0 };
  }
  return {
    founder: netProfit * DISTRIBUTION.FOUNDER,
    advisor: netProfit * DISTRIBUTION.ADVISOR,
    companyFund: netProfit * DISTRIBUTION.COMPANY_FUND,
    teamPool: netProfit * DISTRIBUTION.TEAM_POOL
  };
}

// Calculate equal per-member amount
function calculatePerMemberAmount(teamPool, activeCount) {
  if (activeCount <= 0) return 0;
  return teamPool / activeCount;
}

// Generate monthly payouts
async function generateMonthlyPayouts(payoutMonth, calculatedBy) {
  // payoutMonth = 'YYYY-MM-01' (the month being paid out on 15th)
  // We calculate for the PREVIOUS month's projects
  const calcMonth = getPreviousMonthStart(payoutMonth);
  const calcMonthEnd = getMonthEnd(calcMonth);

  // Check if already generated
  const { data: existing } = await supabase
    .from('payout_calculations')
    .select('id')
    .eq('month', payoutMonth)
    .single();

  if (existing) {
    throw new Error('Payouts already generated for this month. Delete existing first to regenerate.');
  }

  // Get all projects from the calculation month
  const { data: projects, error: projErr } = await supabase
    .from('projects')
    .select('net_profit')
    .gte('project_date', calcMonth)
    .lte('project_date', calcMonthEnd);

  if (projErr) throw projErr;

  // Total net profit
  let totalNetProfit = 0;
  for (const p of (projects || [])) {
    totalNetProfit += parseFloat(p.net_profit) || 0;
  }

  // Distribution
  const dist = calculateDistribution(totalNetProfit);

  // Get founder
  const { data: founder } = await supabase
    .from('users')
    .select('id')
    .eq('role', 'admin')
    .eq('active', true)
    .limit(1)
    .single();

  // Get advisor
  const { data: advisor } = await supabase
    .from('users')
    .select('id')
    .eq('role', 'advisor')
    .eq('active', true)
    .limit(1)
    .single();

  // Get active team members
  const { data: teamMembers } = await supabase
    .from('users')
    .select('id')
    .eq('role', 'team')
    .eq('active', true);

  const activeCount = teamMembers ? teamMembers.length : 0;
  const perMember = calculatePerMemberAmount(dist.teamPool, activeCount);

  // Save calculation record
  const { error: calcErr } = await supabase.from('payout_calculations').insert({
    month: payoutMonth,
    total_net_profit: totalNetProfit,
    founder_amount: dist.founder,
    advisor_amount: dist.advisor,
    company_fund_amount: dist.companyFund,
    team_pool_amount: dist.teamPool,
    active_team_count: activeCount,
    per_member_amount: perMember,
    calculated_by: calculatedBy
  });

  if (calcErr) throw calcErr;

  // Create payout records
  const payouts = [];

  if (founder) {
    payouts.push({ user_id: founder.id, month: payoutMonth, amount: dist.founder, status: 'pending' });
  }

  if (advisor) {
    payouts.push({ user_id: advisor.id, month: payoutMonth, amount: dist.advisor, status: 'pending' });
  }

  for (const member of (teamMembers || [])) {
    payouts.push({ user_id: member.id, month: payoutMonth, amount: perMember, status: 'pending' });
  }

  if (payouts.length > 0) {
    const { error: payErr } = await supabase.from('payouts').insert(payouts);
    if (payErr) throw payErr;
  }

  // Add to company fund
  if (dist.companyFund > 0) {
    // Get current balance
    const { data: lastFund } = await supabase
      .from('company_fund')
      .select('balance')
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    const currentBalance = lastFund ? parseFloat(lastFund.balance) : 0;

    await supabase.from('company_fund').insert({
      transaction_type: 'credit',
      amount: dist.companyFund,
      balance: currentBalance + dist.companyFund,
      description: `Monthly company fund allocation for ${formatMonth(payoutMonth)}`,
      transaction_date: new Date().toISOString().split('T')[0],
      created_by: calculatedBy
    });
  }

  return {
    totalNetProfit,
    distribution: dist,
    activeTeamCount: activeCount,
    perMemberAmount: perMember,
    payoutsCreated: payouts.length
  };
}
