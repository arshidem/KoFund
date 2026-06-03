/**
 * 🎨 PREMIUM LIGHT MODE TEMPLATE FOR SUPER LINKS
 * Designed to match the KoFund App aesthetic.
 */

function escapeHtml(unsafe) {
  if (unsafe === null || unsafe === undefined) return '';
  return String(unsafe)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function getEventHtml({ event, title, date, icon, eventId, downloadUrl, appWebLink }) {
  // 🎨 ICONS (Lucide Style)
  const IconCalendar = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="4" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>`;
  const IconWallet = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12V7H5a2 2 0 0 1 0-4h14v4"/><path d="M3 5v14a2 2 0 0 0 2 2h16v-5"/><path d="M18 12a2 2 0 0 0 0 4h4v-4Z"/></svg>`;
  const IconUsers = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>`;
  const IconFlag = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><line x1="4" y1="22" x2="4" y2="15"/></svg>`;
  const IconChart = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="20" x2="12" y2="10"/><line x1="18" y1="20" x2="18" y2="4"/><line x1="6" y1="20" x2="6" y2="16"/></svg>`;
  const IconInfo = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>`;
  const IconUser = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`;
  const IconDescription = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>`;

  // 📅 Month Selector Trigger & Modal
  let monthSelectorHtml = '';
  if (event.isMonthlyPayment) {
    monthSelectorHtml = `
      <div class="month-selector-trigger" id="month-trigger" onclick="togglePicker()">
        <div style="display: flex; align-items: center; gap: 8px;">
          <span class="icon" style="color: var(--primary);">${IconCalendar}</span>
          <span id="selected-month-name" style="font-weight: 700;">Select Month</span>
        </div>
        <span class="chevron" style="color: var(--text-sec); display: flex;">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
        </span>
      </div>

      <div class="modal-overlay" id="picker-overlay" onclick="togglePicker()">
        <div class="month-modal" onclick="event.stopPropagation()">
          <div class="month-modal-header">
            <h4>Select Month</h4>
            <button class="close-btn" onclick="togglePicker()">&times;</button>
          </div>
          <div class="month-modal-body">
            <div class="year-nav">
              <button class="year-btn" onclick="navYear(-1)">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
              </button>
              <h3 id="year-display" style="margin: 0 15px;">${new Date().getFullYear()}</h3>
              <button class="year-btn" onclick="navYear(1)">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m9 18 6-6-6-6"/></svg>
              </button>
            </div>
            <div class="month-grid" id="month-grid"></div>
            <div class="month-modal-footer">
               <div class="legend-item" onclick="changeMonth('all')" style="cursor: pointer; font-weight: 800; color: var(--primary); width: 100%; text-align: center; background: #00C6A210; padding: 12px; border-radius: 12px;">Show All Time</div>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  // Footer Content
  const footerContent = `
    <div class="app-cta">
      <div class="cta-card">
        <div class="cta-text">
          <strong>Organize your own events?</strong>
          <p>Host collection events, track payments, and manage expenses seamlessly.</p>
        </div>
        <div class="cta-buttons">
          <button onclick="handleAppOpen()" class="cta-btn primary-cta">Open in App</button>
          <a href="https://kofund-153ba.web.app/" class="cta-btn secondary-cta" target="_blank">Web Link</a>
        </div>
      </div>
    </div>
    <div class="footer">
      Powered by <b>KoFund</b> • Making community funding simple
    </div>
  `;

  return `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${escapeHtml(title)} | KoFund</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
      :root {
        --primary: #00C6A2;
        --bg: #F8FAFC;
        --card: #FFFFFF;
        --text: #1E293B;
        --text-sec: #64748B;
        --success: #10B981;
        --danger: #EF4444;
        --border: #E2E8F0;
        --shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
      }
      * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      body { font-family: 'Outfit', sans-serif; background: var(--bg); color: var(--text); line-height: 1.5; padding-top: 60px; padding-bottom: 20px; overflow-x: hidden; }
      
      /* App Bar */
      .top-app-bar { position: fixed; top: 0; left: 0; right: 0; height: 60px; background: var(--primary); z-index: 1001; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
      .app-title-container { display: flex; align-items: center; }
      .app-logo { width: 30px; height: 30px; margin-right: 10px; }
      .app-title { font-size: 20px; font-weight: 800; color: white; letter-spacing: -0.5px; }
      .sticky-title { position: absolute; width: 100%; text-align: center; font-weight: 700; font-size: 16px; color: white; opacity: 0; transform: translateY(10px); transition: 0.3s; pointer-events: none; }
      .scrolled .app-title-container { opacity: 0; transform: translateY(-10px); }
      .scrolled .sticky-title { opacity: 1; transform: translateY(0); }

      /* Header */
      .header { background: white; padding: 30px 20px; border-bottom: 1px solid var(--border); }
      .header h1 { font-size: 24px; font-weight: 800; margin-bottom: 4px; }
      .event-date { font-size: 14px; color: var(--text-sec); font-weight: 500; }

      /* Tabs */
      .tabs-container { position: sticky; top: 60px; z-index: 1000; background: white; border-bottom: 1px solid var(--border); }
      .tabs { display: flex; overflow-x: auto; scrollbar-width: none; }
      .tab-btn { flex: 1; padding: 16px; border: none; background: none; font-size: 14px; font-weight: 600; color: var(--text-sec); cursor: pointer; position: relative; white-space: nowrap; }
      .tab-btn.active { color: var(--primary); }
      .tab-btn.active::after { content: ''; position: absolute; bottom: 0; left: 20%; right: 20%; height: 3px; background: var(--primary); border-radius: 3px; }

      /* Content */
      .content-section { padding: 20px; display: none; }
      .content-section.active { display: block; }

      /* Cards & Stats */
      .premium-card { background: linear-gradient(135deg, #00C6A2, #00E3C3); border-radius: 20px; padding: 24px; color: white; margin-bottom: 20px; box-shadow: 0 10px 25px rgba(0,198,162,0.2); }
      .card-title { font-size: 13px; opacity: 0.9; margin-bottom: 8px; font-weight: 600; }
      .balance-amount { font-size: 32px; font-weight: 800; margin-bottom: 20px; }
      .stat-row { display: flex; justify-content: space-between; }
      .stat-label { font-size: 12px; opacity: 0.7; }
      .stat-val { font-size: 18px; font-weight: 700; }
      
      .progress-track { height: 8px; background: rgba(255,255,255,0.2); border-radius: 4px; margin-top: 15px; overflow: hidden; }
      .progress-fill { height: 100%; background: white; transition: width 0.5s ease-out; }

      /* Info Grid */
      .grid-card { background: white; border-radius: 16px; padding: 16px; border: 1px solid var(--border); margin-bottom: 20px; }
      .header-tile { background: rgba(0,198,162,0.04); border-radius: 12px; padding: 12px; display: flex; align-items: center; margin-bottom: 10px; }
      .header-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
      .tile-label { font-size: 11px; color: var(--text-sec); }
      .tile-val { font-size: 13px; font-weight: 600; }
      .tile-val.highlight { color: var(--primary); font-size: 16px; font-weight: 800; }

      /* Lists */
      .member-row { display: flex; align-items: center; padding: 12px 0; border-bottom: 1px solid var(--border); }
      .member-avatar { width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 800; margin-right: 12px; font-size: 13px; }
      .member-info { flex: 1; }
      .member-name { font-size: 14px; font-weight: 700; }
      .member-amount { font-size: 15px; font-weight: 800; color: var(--primary); }
      .member-due { font-size: 10px; color: var(--text-sec); font-weight: 600; }

      .list-container { background: white; border-radius: 16px; padding: 10px 20px; border: 1px solid var(--border); }
      .list-item { display: flex; align-items: center; padding: 12px 0; border-bottom: 1px solid #F1F5F9; }
      .list-amount { font-weight: 700; color: var(--success); font-size: 15px; }
      .list-amount.expense { color: var(--danger); }

      /* Month Picker Trigger */
      .month-selector-trigger { background: white; border: 1.5px solid var(--border); border-radius: 16px; padding: 14px 20px; display: flex; align-items: center; justify-content: space-between; cursor: pointer; margin-top: 15px; box-shadow: var(--shadow); transition: all 0.2s; }
      .month-selector-trigger:hover { border-color: var(--primary); background: #F8FAFC; }
      #month-trigger { display: none; } /* Initially hidden until unlocked */

      /* Month Modal Overlay */
      .modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.4); backdrop-filter: blur(5px); z-index: 3000; display: none; align-items: center; justify-content: center; padding: 20px; animation: fadeIn 0.2s ease-out; }
      @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

      .month-modal { background: white; width: 100%; max-width: 380px; border-radius: 28px; overflow: hidden; box-shadow: 0 20px 50px rgba(0,0,0,0.2); animation: slideUp 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); }
      @keyframes slideUp { from { transform: translateY(20px) scale(0.95); opacity: 0; } to { transform: translateY(0) scale(1); opacity: 1; } }

      .month-modal-header { padding: 20px 24px; background: white; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid var(--border); }
      .month-modal-header h4 { font-size: 18px; font-weight: 800; }
      .close-btn { background: #F1F5F9; border: none; width: 32px; height: 32px; border-radius: 50%; font-size: 20px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: var(--text-sec); }

      .month-modal-body { padding: 15px; }
      .month-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; padding: 10px; }
      .month-box { aspect-ratio: 1.4; border-radius: 14px; border: 1px solid var(--border); display: flex; align-items: center; justify-content: center; cursor: pointer; font-weight: 700; font-size: 14px; background: #F8FAFC; transition: all 0.2s; }
      .month-box.active { background: var(--primary); color: white; border-color: var(--primary); transform: scale(1.05); }
      .month-box:hover:not(.active) { background: white; border-color: var(--primary); color: var(--primary); }

      .year-nav { display: flex; align-items: center; justify-content: center; margin-bottom: 15px; }
      .year-btn { border: 1.5px solid var(--border); background: white; border-radius: 12px; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center; color: var(--primary); cursor: pointer; transition: 0.2s; }
      .year-btn:hover { border-color: var(--primary); background: #f0fffb; }
      .month-modal-footer { margin-top: 15px; padding: 0 10px 10px; }

      /* Password Modal */
      #password-overlay { position: fixed; inset: 0; background: rgba(255,255,255,0.9); backdrop-filter: blur(10px); z-index: 2000; display: none; align-items: center; justify-content: center; padding: 20px; }
      .pwd-card { background: white; width: 100%; max-width: 350px; border-radius: 24px; padding: 30px; box-shadow: 0 20px 50px rgba(0,0,0,0.1); text-align: center; border: 1px solid var(--border); }
      .pwd-card h2 { font-size: 22px; font-weight: 800; margin-bottom: 8px; }
      .pwd-card p { font-size: 14px; color: var(--text-sec); margin-bottom: 25px; }
      .pwd-input { width: 100%; padding: 15px; border-radius: 12px; border: 1.5px solid var(--border); font-family: inherit; font-size: 16px; margin-bottom: 15px; outline: none; text-align: center; }
      .pwd-input:focus { border-color: var(--primary); }
      .pwd-btn { width: 100%; padding: 15px; border-radius: 12px; border: none; background: var(--primary); color: white; font-weight: 700; font-size: 16px; cursor: pointer; }
      .pwd-error { color: var(--danger); font-size: 12px; margin-bottom: 10px; display: none; }

      /* Skeleton */
      .skeleton { background: #f0f0f4; border-radius: 10px; background-image: linear-gradient(90deg, #f0f0f4, #f8f8fa, #f0f0f4); background-size: 200px 100%; animation: shimmer 1.5s infinite linear; }
      @keyframes shimmer { 0% { background-position: -200px 0; } 100% { background-position: 200px 0; } }
      .sk-text { height: 20px; margin-bottom: 10px; width: 80%; }
      .sk-card { height: 150px; margin-bottom: 20px; border-radius: 20px; }

      #loader { position: fixed; inset: 0; background: rgba(255,255,255,0.7); display: none; align-items: center; justify-content: center; z-index: 3000; }
      .spinner { width: 40px; height: 40px; border: 4px solid #f3f3f3; border-top: 4px solid var(--primary); border-radius: 50%; animation: spin 1s linear infinite; }
      @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
      
      .cta-card { background: white; border: 1px solid var(--border); border-radius: 16px; padding: 20px; text-align: center; margin: 20px; }
      .cta-btn { padding: 12px; border-radius: 25px; font-weight: 700; border: none; flex: 1; cursor: pointer; text-decoration: none; }
      .primary-cta { background: var(--text); color: white; margin-right: 10px; }
      .secondary-cta { background: #F1F5F9; color: var(--text); display: inline-block; }
      .footer { text-align: center; padding: 20px; font-size: 12px; color: var(--text-sec); }
    </style>
  </head>
  <body onscroll="handleScroll()">
    <div id="loader"><div class="spinner"></div></div>

    <div id="password-overlay">
      <div class="pwd-card">
        <h2>Private Event</h2>
        <p>This event is protected. Please enter the password to view details.</p>
        <div id="pwd-error" class="pwd-error">Invalid password. Try again.</div>
        <input type="password" id="pwd-input" class="pwd-input" placeholder="Enter Password" autofocus>
        <button onclick="submitPassword()" class="pwd-btn">Unlock Now</button>
      </div>
    </div>

    <div class="top-app-bar" id="appbar">
      <div class="app-title-container">
        <div class="app-logo">
          <svg viewBox="0 0 96 90.59"><polygon points="89.84 0 23.76 66.63 0 90.59 0 15.9 23.76 15.9 23.76 47.01 89.84 0" style="fill: #052224;"/><polygon points="84.66 90.59 52.18 90.59 31.7 69.71 48.04 53.24 84.66 90.59" style="fill: #fff;"/><polygon points="96 4.88 67.69 60.18 54.5 46.73 96 4.88" style="fill: #fff;"/></svg>
        </div>
        <div class="app-title">KoFund</div>
      </div>
      <div class="sticky-title">${escapeHtml(title)}</div>
    </div>

    <div class="header" id="main-header">
      <h1>${escapeHtml(title)}</h1>
      <div class="event-date" id="event-date-display">${escapeHtml(date)}</div>
      ${monthSelectorHtml}
    </div>

    <div class="tabs-container">
      <div class="tabs">
        <button class="tab-btn active" id="btn-overview" onclick="showTab('overview')">Overview</button>
        <button class="tab-btn" id="btn-participants" onclick="showTab('participants')">Members</button>
        <button class="tab-btn" id="btn-expenses" onclick="showTab('expenses')">Expenses</button>
      </div>
    </div>

    <div id="overview" class="content-section active">
      <div class="skeleton sk-card"></div>
      <div class="skeleton sk-text"></div>
      <div class="skeleton sk-text"></div>
    </div>
    
    <div id="participants" class="content-section">
      <div class="member-row"><div class="skeleton sk-text" style="width: 100%;"></div></div>
      <div class="member-row"><div class="skeleton sk-text" style="width: 100%;"></div></div>
    </div>

    <div id="expenses" class="content-section">
      <div class="list-container"><div class="skeleton sk-text" style="width: 100%;"></div></div>
    </div>

    ${footerContent}

    <script>
      const eventId = "${eventId}";
      const downloadUrl = "${downloadUrl}";
      let currentMonth = "all";
      let displayYear = new Date().getFullYear();

      // 🔐 PERSISTENT SESSION LOGIC
      const SESSION_KEY = "event_session_" + eventId;

      function getSession() {
        const data = localStorage.getItem(SESSION_KEY);
        if (!data) return null;
        try { return JSON.parse(data); } catch (e) { return null; }
      }

      function setSession(pwd) {
        localStorage.setItem(SESSION_KEY, JSON.stringify({ password: pwd }));
      }

      async function init() {
        const hasPassword = ${!!event.hasPassword};
        if (!hasPassword) {
          await fetchData('');
          return;
        }
        const session = getSession();
        if (session && session.password) {
          const success = await fetchData(session.password);
          if (!success) {
            document.getElementById('password-overlay').style.display = 'flex';
          }
        } else {
          document.getElementById('password-overlay').style.display = 'flex';
        }
      }

      async function submitPassword() {
        const input = document.getElementById('pwd-input');
        const pwd = input.value;
        if (!pwd) return;
        
        document.getElementById('loader').style.display = 'flex';
        const success = await fetchData(pwd);
        document.getElementById('loader').style.display = 'none';
        
        if (success) {
          setSession(pwd);
          document.getElementById('password-overlay').style.display = 'none';
          document.getElementById('pwd-error').style.display = 'block';
          input.value = '';
          input.focus();
        }
      }

      async function fetchData(pwd, month = currentMonth) {
        try {
          const url = new URL(window.location.href);
          url.searchParams.set('json', 'true');
          url.searchParams.set('password', pwd);
          url.searchParams.set('month', month);
          
          const res = await fetch(url.toString());
          if (res.status === 401 || res.status === 403) {
            document.getElementById('password-overlay').style.display = 'flex';
            document.getElementById('pwd-error').innerText = 'Password has changed. Please re-enter.';
            document.getElementById('pwd-error').style.display = 'block';
            return false;
          }
          if (!res.ok) throw new Error();
          
          const data = await res.json();
          updateUI(data, month);
          return true;
        } catch (e) {
          return false;
        }
      }

      function updateUI(data, monthId) {
        currentMonth = monthId;
        const { event, participants, expenses, totalCollected, totalExpenses } = data;
        
        const trigger = document.getElementById('month-trigger');
        if (trigger) {
          trigger.style.display = 'flex';
          const monthLabel = document.getElementById('selected-month-name');
          if (monthId === 'all') {
            monthLabel.innerText = 'All Time View';
          } else {
            const [y, m] = monthId.split('-');
            const date = new Date(y, parseInt(m)-1);
            monthLabel.innerText = date.toLocaleString('en-US', { month: 'long', year: 'numeric' });
          }
        }

        const balance = (totalCollected || 0) - (totalExpenses || 0);
        const target = event.totalAmount || ((event.suggestedContribution || 0) * (event.maxParticipants || 1));
        const progress = target > 0 ? (totalCollected / target) : 0;
        
        const ov = document.getElementById('overview');
        ov.innerHTML = \`
          <div class="premium-card">
            <div class="card-title">Financial Summary \${monthId !== 'all' ? '('+monthId+')' : ''}</div>
            <div class="balance-amount">₹\${balance.toLocaleString('en-IN', {minimumFractionDigits: 2})}</div>
            <div class="stat-row">
              <div class="stat-item"><div class="stat-label">Collected</div><div class="stat-val">₹\${(totalCollected || 0).toLocaleString('en-IN')}</div></div>
              <div class="stat-item" style="text-align:right"><div class="stat-label">Expenses</div><div class="stat-val">₹\${(totalExpenses || 0).toLocaleString('en-IN')}</div></div>
            </div>
            \${target > 0 ? \`
              <div class="progress-track"><div class="progress-fill" style="width: \${Math.min(progress*100, 100)}%"></div></div>
            \` : ''}
          </div>
          <div class="grid-card">
            <div class="header-tile"><div class="tile-label">Members</div><div class="tile-val highlight">\${event.participantType === 'fixed' ? participants.length + ' / ' + event.maxParticipants : participants.length}</div></div>
            <div class="header-grid">
              <div class="header-tile"><div class="tile-label">Contribution</div><div class="tile-val">₹\${event.suggestedContribution || 0}</div></div>
              <div class="header-tile"><div class="tile-label">Status</div><div class="tile-val">\${event.status || 'Active'}</div></div>
            </div>
          </div>
        \`;

        const ps = document.getElementById('participants');
        if (participants.length === 0) {
          ps.innerHTML = '<div class="empty-state">No participants yet.</div>';
        } else {
          ps.innerHTML = participants.map(p => \`
            <div class="member-row">
              <div class="member-avatar" style="background:#00C6A215;color:#00C6A2">\${escapeHtml((p.userName || 'M').charAt(0))}</div>
              <div class="member-info"><div class="member-name">\${escapeHtml(p.userName)}</div></div>
              <div class="member-amount">₹\${Math.floor(p.contributionPaid || 0).toLocaleString('en-IN')}</div>
            </div>
          \`).join('');
        }

        const es = document.getElementById('expenses');
        if (expenses.length === 0) {
          es.innerHTML = '<div class="empty-state">No expenses yet.</div>';
        } else {
          es.innerHTML = '<div class="list-container">' + expenses.map(e => \`
            <div class="list-item">
              <div class="member-info"><div class="member-name">\${escapeHtml(e.title)}</div><div class="member-due">\${e.expenseDate ? new Date(e.expenseDate.seconds * 1000).toLocaleDateString() : ''}</div></div>
              <div class="list-amount expense">-₹\${(e.amount || 0).toLocaleString('en-IN')}</div>
            </div>
          \`).join('') + '</div>';
        }
      }

      function togglePicker() {
        const overlay = document.getElementById('picker-overlay');
        const isShown = overlay.style.display === 'flex';
        overlay.style.display = isShown ? 'none' : 'flex';
        if (!isShown) renderMonthGrid();
      }

      function renderMonthGrid() {
        const grid = document.getElementById('month-grid');
        if (!grid) return;
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        document.getElementById('year-display').innerText = displayYear;
        grid.innerHTML = months.map((m, i) => {
          const mId = displayYear + '-' + String(i + 1).padStart(2, '0');
          const isActive = currentMonth === mId ? 'active' : '';
          return \`<div class="month-box \${isActive}" onclick="changeMonth('\${mId}')">\${m}</div>\`;
        }).join('');
      }

      function navYear(off) { displayYear += off; renderMonthGrid(); }

      async function changeMonth(mId) {
        togglePicker(); 
        document.getElementById('loader').style.display = 'flex';
        const session = getSession();
        await fetchData(session ? session.password : '', mId);
        document.getElementById('loader').style.display = 'none';
      }

      function showTab(id) {
        document.querySelectorAll('.content-section').forEach(s => s.classList.remove('active'));
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.getElementById(id).classList.add('active');
        document.getElementById('btn-' + id).classList.add('active');
      }

      function handleScroll() {
        const scroll = window.pageYOffset;
        if (scroll > 100) document.getElementById('appbar').classList.add('scrolled');
        else document.getElementById('appbar').classList.remove('scrolled');
      }

      function handleAppOpen() {
        const deepLink = "kofund://open";
        const startTime = Date.now();
        
        // Attempt to open the app
        window.location.href = deepLink;
        
        // Fallback check after 1.5 seconds
        setTimeout(() => {
          if (Date.now() - startTime < 2000) {
            // App didn't open or browser didn't lose focus
            if (confirm("KoFund app not detected. Would you like to download it now?")) {
              window.location.href = downloadUrl;
            }
          }
        }, 1500);
      }

      window.onload = init;

      // 🛡️ SECURITY: HTML Escaping for client-side injection
      function escapeHtml(unsafe) {
        if (!unsafe) return '';
        return String(unsafe)
          .replace(/&/g, "&amp;")
          .replace(/</g, "&lt;")
          .replace(/>/g, "&gt;")
          .replace(/"/g, "&quot;")
          .replace(/'/g, "&#39;");
      }
    </script>
  </body>
  </html>
  `;
}

function getPrivateEventHtml({ title }) {
  return `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Private Event | KoFund</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
      :root {
        --primary: #00C6A2;
        --bg: #F8FAFC;
        --text: #1E293B;
        --text-sec: #64748B;
        --border: #E2E8F0;
      }
      body { font-family: 'Outfit', sans-serif; background: var(--bg); display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; padding: 20px; color: var(--text); }
      .card { background: white; padding: 40px 30px; border-radius: 28px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); width: 100%; max-width: 400px; text-align: center; border: 1px solid var(--border); }
      .icon-container { width: 80px; height: 80px; background: rgba(0, 198, 162, 0.1); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px; }
      h1 { font-size: 24px; font-weight: 800; margin-bottom: 12px; }
      p { color: var(--text-sec); font-size: 15px; margin-bottom: 30px; line-height: 1.6; }
      .btn { display: block; width: 100%; background: var(--primary); color: white; padding: 16px; border-radius: 12px; font-weight: 700; text-decoration: none; transition: 0.2s; box-shadow: 0 4px 12px rgba(0, 198, 162, 0.2); }
      .btn:hover { opacity: 0.9; transform: translateY(-2px); }
    </style>
  </head>
  <body>
    <div class="card">
      <div class="icon-container">
        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
      </div>
      <h1>This Event is Private</h1>
      <p>The organizer has disabled public link sharing for this event. You can still access it directly in the KoFund app if you are a participant.</p>
      <a href="https://kofund.app" class="btn">Open KoFund App</a>
    </div>
  </body>
  </html>
  `;
}

function getPrivacyPolicyHtml() {
  return `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy | KoFund</title>
    <meta name="description" content="KoFund Privacy Policy — learn how we collect, use, and protect your data.">
    <meta name="google-site-verification" content="PLACEHOLDER_GOOGLE_VERIFICATION_KEY" />
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
      :root {
        --primary: #00C6A2;
        --bg: #F8FAFC;
        --card: #FFFFFF;
        --text: #1E293B;
        --text-sec: #64748B;
        --success: #10B981;
        --danger: #EF4444;
        --border: #E2E8F0;
        --shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
      }
      * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      body { font-family: 'Outfit', sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; padding-top: 80px; padding-bottom: 40px; }
      
      /* App Bar */
      .top-app-bar { position: fixed; top: 0; left: 0; right: 0; height: 60px; background: var(--primary); z-index: 1001; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
      .app-title-container { display: flex; align-items: center; }
      .app-logo { width: 30px; height: 30px; margin-right: 10px; }
      .app-title { font-size: 20px; font-weight: 800; color: white; letter-spacing: -0.5px; }

      .container { max-width: 800px; margin: 0 auto; padding: 0 20px; }
      
      /* Header Card */
      .header-card { background: white; padding: 30px; border-radius: 24px; border: 1px solid var(--border); box-shadow: var(--shadow); text-align: center; margin-bottom: 24px; }
      .icon-container { width: 64px; height: 64px; background: rgba(0, 198, 162, 0.1); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; color: var(--primary); }
      .header-card h1 { font-size: 26px; font-weight: 800; margin-bottom: 8px; color: var(--text); }
      .effective-badge { display: inline-block; padding: 6px 16px; background: rgba(0, 198, 162, 0.1); color: var(--primary); border-radius: 20px; border: 1px solid rgba(0, 198, 162, 0.3); font-size: 13px; font-weight: 600; margin-bottom: 12px; }
      .tagline { color: var(--text-sec); font-size: 14px; font-style: italic; }

      /* Notice Card */
      .notice-card { background: #eff6ff; border-radius: 20px; padding: 20px; border: 1.5px solid #93c5fd; display: flex; gap: 14px; margin-bottom: 24px; }
      .notice-icon { color: #1d4ed8; flex-shrink: 0; }
      .notice-title { font-size: 16px; font-weight: 700; color: #1e3a8a; margin-bottom: 4px; }
      .notice-desc { color: #1e40af; font-size: 13.5px; }

      /* Sections */
      .section-card { background: white; border-radius: 16px; padding: 24px; border: 1px solid var(--border); margin-bottom: 20px; }
      .section-title { font-size: 18px; font-weight: 700; color: var(--text); margin-bottom: 12px; border-bottom: 2px solid #F1F5F9; padding-bottom: 8px; }
      .section-content { color: var(--text-sec); font-size: 14px; white-space: pre-line; }

      /* Rights Card */
      .rights-card { background: white; border-radius: 16px; padding: 24px; border: 1px solid var(--border); margin-bottom: 20px; }
      .rights-title-row { display: flex; align-items: center; gap: 10px; margin-bottom: 16px; }
      .rights-title { font-size: 16px; font-weight: 700; }
      .rights-box { background: var(--bg); border-radius: 12px; padding: 16px; border: 1px solid var(--border); }
      .rights-header { font-weight: 600; margin-bottom: 12px; display: flex; align-items: center; gap: 8px; font-size: 14px; }
      .right-item { display: flex; align-items: flex-start; gap: 8px; margin-bottom: 8px; font-size: 13px; color: var(--text-sec); }
      .right-item:last-child { margin-bottom: 0; }
      .check-icon { color: var(--primary); flex-shrink: 0; }

      /* Contact Card */
      .contact-card { background: white; border-radius: 16px; padding: 20px; border: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; text-decoration: none; color: inherit; transition: border-color 0.2s; margin-bottom: 30px; }
      .contact-card:hover { border-color: var(--primary); }
      .contact-info { display: flex; align-items: center; gap: 14px; }
      .contact-icon { width: 44px; height: 44px; background: rgba(16, 185, 129, 0.1); color: #10b981; border-radius: 12px; display: flex; align-items: center; justify-content: center; }
      .contact-details h4 { font-size: 15px; font-weight: 700; }
      .contact-details p { font-size: 13.5px; color: var(--primary); }
      .arrow-icon { color: var(--text-sec); }

      /* Footer */
      .footer { text-align: center; font-size: 12px; color: var(--text-sec); padding-top: 20px; border-top: 1px solid var(--border); }
    </style>
  </head>
  <body>
    <div class="top-app-bar">
      <div class="app-title-container">
        <div class="app-logo">
          <svg viewBox="0 0 96 90.59"><polygon points="89.84 0 23.76 66.63 0 90.59 0 15.9 23.76 15.9 23.76 47.01 89.84 0" style="fill: #052224;"/><polygon points="84.66 90.59 52.18 90.59 31.7 69.71 48.04 53.24 84.66 90.59" style="fill: #fff;"/><polygon points="96 4.88 67.69 60.18 54.5 46.73 96 4.88" style="fill: #fff;"/></svg>
        </div>
        <div class="app-title">KoFund</div>
      </div>
    </div>

    <div class="container">
      <div class="header-card">
        <div class="icon-container">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
        </div>
        <h1>Privacy Policy</h1>
        <div class="effective-badge">Effective: June 2026</div>
        <p class="tagline">Your privacy is important to us. This policy explains how we handle your data.</p>
      </div>

      <div class="notice-card">
        <div class="notice-icon">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
        </div>
        <div>
          <div class="notice-title">Data Protection Notice</div>
          <div class="notice-desc">We do NOT collect banking details, card information, or payment data. KoFund is a record-keeping tool only. All transactions are managed outside of the app.</div>
        </div>
      </div>

      <div class="section-card">
        <h2 class="section-title">1. Information We Collect</h2>
        <div class="section-content">We may collect the following types of data:

a) Personal Information
• Name, email address, or phone number (if provided during account creation)
• Profile photo (if uploaded by the user)

b) Group &amp; Activity Data
• Contribution records entered by group administrators
• Expense records and descriptions
• Group activity history and event participation records
• Community membership information

c) Technical Information
• Device type and operating system version
• App usage patterns and feature interactions
• Crash reports and performance diagnostics
• Firebase Cloud Messaging (FCM) tokens for push notifications

We do NOT collect banking details, card numbers, UPI IDs, or any payment credentials.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">2. How We Use Your Information</h2>
        <div class="section-content">We use your data exclusively to:

• Provide and operate core KoFund features (group funds, event tracking, contributions)
• Display group fund records and financial summaries to authorized members
• Send push notifications for events, reminders, and announcements
• Improve app performance, fix bugs, and enhance user experience
• Communicate important service updates or policy changes
• Identify and prevent misuse or fraudulent activity</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">3. Data Sharing &amp; Third Parties</h2>
        <div class="section-content">• We do not sell, trade, rent, or share personal data with advertisers
• Contribution and expense data is visible only to members within the same community group
• We use Firebase (Google) for authentication, database, and push notifications — governed by Google's privacy policy
• Crash reporting may be processed by Firebase Crashlytics
• No personal data is shared with any third party for marketing purposes</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">4. Data Storage &amp; Security</h2>
        <div class="section-content">• All data is stored on Google Firebase Cloud Firestore with industry-standard encryption
• Authentication is handled securely via Firebase Authentication
• We apply access control rules so only authorized group members can view their community's data
• We take reasonable technical steps to protect your data from unauthorized access
• No system is completely immune to breaches; use of KoFund is at your own risk</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">5. Data Retention</h2>
        <div class="section-content">• Your account profile data is retained as long as your account is active
• Group contribution and expense records are retained as part of the community's shared history, even if you leave or are removed from a group
• Account deletion removes your personal profile data (name, email, FCM tokens) from the users collection
• Historical contribution records tied to your user ID may remain for group transparency and audit purposes
• FCM notification tokens are automatically deactivated upon logout or inactivity</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">6. Your Rights</h2>
        <div class="section-content">You have the right to:

• Access your account information at any time through the app
• Update or correct your profile data within the app settings
• Request deletion of your personal profile data via the Delete Account page
• Opt out of push notifications through your device settings
• Contact us for any privacy-related queries or concerns

Note: Requests may be limited where your data forms part of a shared group's historical records.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">7. Children's Privacy</h2>
        <div class="section-content">KoFund is intended for users aged 13 and above.
We do not knowingly collect personal data from children under the age of 13.
If we discover that a child under 13 has created an account, we will delete the associated data promptly.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">8. Changes to This Policy</h2>
        <div class="section-content">We may update this Privacy Policy periodically to reflect changes in our practices or applicable laws.
When we make significant changes, we will notify you through the app or via email.
Continued use of KoFund after updates constitutes your acceptance of the revised policy.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">9. Contact Us</h2>
        <div class="section-content">For privacy questions, data requests, or concerns, please reach out to us:</div>
      </div>

      <a href="mailto:kofundapp@gmail.com?subject=Privacy%20Policy%20Inquiry" class="contact-card">
        <div class="contact-info">
          <div class="contact-icon">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
          </div>
          <div class="contact-details">
            <h4>Privacy Support</h4>
            <p>kofundapp@gmail.com</p>
          </div>
        </div>
        <div class="arrow-icon">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m9 18 6-6-6-6"/></svg>
        </div>
      </a>

      <div class="rights-card">
        <div class="rights-title-row">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          <div class="rights-title">Your Privacy Rights</div>
        </div>
        <div class="rights-box">
          <div class="rights-header">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
            You have the right to:
          </div>
          <div class="right-item"><span class="check-icon">✓</span> Know what personal data we hold about you</div>
          <div class="right-item"><span class="check-icon">✓</span> Access and update your profile information</div>
          <div class="right-item"><span class="check-icon">✓</span> Request deletion of your account and personal data</div>
          <div class="right-item"><span class="check-icon">✓</span> Understand how your data is used and shared</div>
          <div class="right-item"><span class="check-icon">✓</span> Opt out of push notifications at any time</div>
          <div class="right-item"><span class="check-icon">✓</span> Contact us with privacy questions or concerns</div>
        </div>
      </div>

      <div class="footer">
        <p>KoFund Privacy Policy</p>
        <p style="margin-top: 4px; font-size: 11px;">Version 2.0 • Last updated: June 2026</p>
        <p style="margin-top: 4px; font-size: 11px;">© 2026 KoFund. All rights reserved.</p>
      </div>
    </div>
  </body>
  </html>
  `;
}

function getTermsOfServiceHtml() {
  return `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terms of Service | KoFund</title>
    <!-- Google / Apple Site Verification (Optional placeholders) -->
    <meta name="google-site-verification" content="PLACEHOLDER_GOOGLE_VERIFICATION_KEY" />
    <meta name="apple-itunes-app" content="app-id=PLACEHOLDER_APP_ID" />
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
      :root {
        --primary: #00C6A2;
        --bg: #F8FAFC;
        --card: #FFFFFF;
        --text: #1E293B;
        --text-sec: #64748B;
        --border: #E2E8F0;
        --shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
      }
      * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      body { font-family: 'Outfit', sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; padding-top: 80px; padding-bottom: 40px; }
      
      /* App Bar */
      .top-app-bar { position: fixed; top: 0; left: 0; right: 0; height: 60px; background: var(--primary); z-index: 1001; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
      .app-title-container { display: flex; align-items: center; }
      .app-logo { width: 30px; height: 30px; margin-right: 10px; }
      .app-title { font-size: 20px; font-weight: 800; color: white; letter-spacing: -0.5px; }

      .container { max-width: 800px; margin: 0 auto; padding: 0 20px; }
      
      /* Header Card */
      .header-card { background: white; padding: 30px; border-radius: 24px; border: 1px solid var(--border); box-shadow: var(--shadow); text-align: center; margin-bottom: 24px; }
      .icon-container { width: 64px; height: 64px; background: rgba(0, 198, 162, 0.1); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; color: var(--primary); }
      .header-card h1 { font-size: 26px; font-weight: 800; margin-bottom: 8px; color: var(--text); }
      .effective-badge { display: inline-block; padding: 6px 16px; background: rgba(0, 198, 162, 0.1); color: var(--primary); border-radius: 20px; border: 1px solid rgba(0, 198, 162, 0.3); font-size: 13px; font-weight: 600; margin-bottom: 12px; }
      .tagline { color: var(--text-sec); font-size: 14px; font-style: italic; }

      /* Notice Card */
      .notice-card { background: #fffbeb; border-radius: 20px; padding: 20px; border: 1.5px solid #fde68a; display: flex; gap: 14px; margin-bottom: 24px; }
      .notice-icon { color: #d97706; flex-shrink: 0; }
      .notice-title { font-size: 16px; font-weight: 700; color: #78350f; margin-bottom: 4px; }
      .notice-desc { color: #92400e; font-size: 13.5px; }

      /* Sections */
      .section-card { background: white; border-radius: 16px; padding: 24px; border: 1px solid var(--border); margin-bottom: 20px; }
      .section-title { font-size: 18px; font-weight: 700; color: var(--text); margin-bottom: 12px; border-bottom: 2px solid #F1F5F9; padding-bottom: 8px; }
      .section-content { color: var(--text-sec); font-size: 14px; white-space: pre-line; }

      /* Acceptance Card */
      .rights-card { background: white; border-radius: 16px; padding: 24px; border: 1px solid var(--border); margin-bottom: 20px; }
      .rights-title-row { display: flex; align-items: center; gap: 10px; margin-bottom: 16px; }
      .rights-title { font-size: 16px; font-weight: 700; }
      .rights-box { background: var(--bg); border-radius: 12px; padding: 16px; border: 1px solid var(--border); }
      .rights-header { font-weight: 600; margin-bottom: 12px; display: flex; align-items: center; gap: 8px; font-size: 14px; }
      .right-item { display: flex; align-items: flex-start; gap: 8px; margin-bottom: 8px; font-size: 13px; color: var(--text-sec); }
      .right-item:last-child { margin-bottom: 0; }
      .check-icon { color: var(--primary); flex-shrink: 0; }

      /* Contact Card */
      .contact-card { background: white; border-radius: 16px; padding: 20px; border: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; text-decoration: none; color: inherit; transition: border-color 0.2s; margin-bottom: 30px; }
      .contact-card:hover { border-color: var(--primary); }
      .contact-info { display: flex; align-items: center; gap: 14px; }
      .contact-icon { width: 44px; height: 44px; background: rgba(59, 130, 246, 0.1); color: #3b82f6; border-radius: 12px; display: flex; align-items: center; justify-content: center; }
      .contact-details h4 { font-size: 15px; font-weight: 700; }
      .contact-details p { font-size: 13.5px; color: var(--primary); }
      .arrow-icon { color: var(--text-sec); }

      /* Footer */
      .footer { text-align: center; font-size: 12px; color: var(--text-sec); padding-top: 20px; border-top: 1px solid var(--border); }
    </style>
  </head>
  <body>
    <div class="top-app-bar">
      <div class="app-title-container">
        <div class="app-logo">
          <svg viewBox="0 0 96 90.59"><polygon points="89.84 0 23.76 66.63 0 90.59 0 15.9 23.76 15.9 23.76 47.01 89.84 0" style="fill: #052224;"/><polygon points="84.66 90.59 52.18 90.59 31.7 69.71 48.04 53.24 84.66 90.59" style="fill: #fff;"/><polygon points="96 4.88 67.69 60.18 54.5 46.73 96 4.88" style="fill: #fff;"/></svg>
        </div>
        <div class="app-title">KoFund</div>
      </div>
    </div>

    <div class="container">
      <div class="header-card">
        <div class="icon-container">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/><polyline points="14 2 14 8 20 8"/></svg>
        </div>
        <h1>Terms of Service</h1>
        <div class="effective-badge">Last updated: June 2026</div>
        <p class="tagline">By accessing or using KoFund, you agree to these Terms of Service.</p>
      </div>

      <div class="notice-card">
        <div class="notice-icon">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
        </div>
        <div>
          <div class="notice-title">Important Notice</div>
          <div class="notice-desc">KoFund is a record-keeping tool only. We do NOT handle, store, or process real money. All financial transactions occur outside the app between group members directly.</div>
        </div>
      </div>

      <div class="section-card">
        <h2 class="section-title">1. Acceptance of Terms</h2>
        <div class="section-content">By downloading, accessing, or using KoFund, you agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree to these terms, please do not use the app.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">2. Purpose of KoFund</h2>
        <div class="section-content">KoFund is a record-keeping and transparency tool designed for groups and communities to track contributions and expenses for shared activities such as trips, tournaments, club events, and community funds.

KoFund does NOT:
• Handle, store, transfer, or process real money or payments
• Act as a payment gateway, wallet, or financial intermediary
• Provide any banking or financial services

All actual financial transactions occur outside the app, directly between community members.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">3. User Accounts &amp; Roles</h2>
        <div class="section-content">• KoFund uses Firebase Authentication for secure account creation and login
• Community groups may have different roles: Administrators and Members
• Administrators are responsible for creating groups, managing members, and entering/editing contribution and expense records
• Members may view group records as permitted by their administrator
• You are solely responsible for maintaining the security of your account credentials
• You are responsible for the accuracy of any information you enter into the app</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">4. Contributions &amp; Expense Records</h2>
        <div class="section-content">• All contribution and expense data is user-entered and not verified by KoFund
• KoFund does not validate the accuracy, completeness, or authenticity of any financial records
• KoFund is not responsible for errors, omissions, disputes, or losses related to group funds
• Any financial disagreements must be resolved directly between group members
• KoFund's public event links display data exactly as entered by community administrators</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">5. Data Retention &amp; History</h2>
        <div class="section-content">For transparency and group accountability:

• Contribution and expense history may remain visible even after a member is removed or leaves a group
• Deleting your personal account removes your profile data but may not erase historical records that form part of a group's shared activity history
• Community administrators are responsible for managing and maintaining their group's records</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">6. User Conduct</h2>
        <div class="section-content">By using KoFund, you agree NOT to:
• Enter false, fraudulent, or misleading contribution or expense data
• Use the app for any illegal or unauthorized purpose
• Harass, threaten, or abuse other community members
• Attempt to reverse-engineer, hack, or disrupt the app or its servers
• Impersonate another user or community administrator

Violation of these rules may result in immediate account suspension or termination.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">7. Account Suspension &amp; Termination</h2>
        <div class="section-content">KoFund reserves the right to suspend or permanently terminate accounts that:
• Violate these Terms of Service
• Engage in fraudulent or abusive behavior
• Are reported by community administrators for serious misconduct

We also reserve the right to modify, discontinue, or update any app features at any time without prior notice.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">8. Limitation of Liability</h2>
        <div class="section-content">KoFund is provided "as is" without any warranties of any kind.

• We are not liable for any financial losses, disputes, or decisions made based on data entered in the app
• We are not responsible for service interruptions, data loss, or technical failures beyond our reasonable control
• Our total liability to you for any claim shall not exceed the amount you paid to use KoFund (which is $0 for free users)

Use of KoFund is entirely at your own risk.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">9. Privacy</h2>
        <div class="section-content">How we collect, use, and protect your personal data is fully described in our Privacy Policy. By using KoFund, you also agree to our Privacy Policy. We encourage you to review it carefully.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">10. Intellectual Property</h2>
        <div class="section-content">• KoFund, its logo, design, and all related content are the intellectual property of the KoFund team
• You may not copy, reproduce, or redistribute any part of the app without explicit written permission
• User-entered data (contributions, expenses) remains the property of the respective community group</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">11. Changes to These Terms</h2>
        <div class="section-content">We may update these Terms of Service from time to time. When significant changes are made, we will notify users through the app or via email where possible.
Continued use of KoFund after changes are posted constitutes your acceptance of the updated terms.</div>
      </div>

      <div class="section-card">
        <h2 class="section-title">12. Contact &amp; Support</h2>
        <div class="section-content">For questions, support, or concerns about these Terms, contact us at:</div>
      </div>

      <a href="mailto:kofundapp@gmail.com?subject=Terms%20of%20Service%20Inquiry" class="contact-card">
        <div class="contact-info">
          <div class="contact-icon">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
          </div>
          <div class="contact-details">
            <h4>Email Support</h4>
            <p>kofundapp@gmail.com</p>
          </div>
        </div>
        <div class="arrow-icon">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m9 18 6-6-6-6"/></svg>
        </div>
      </a>

      <div class="rights-card">
        <div class="rights-title-row">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
          <div class="rights-title">Your Agreement</div>
        </div>
        <div class="rights-box">
          <div class="rights-header">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
            By continuing to use KoFund, you acknowledge that:
          </div>
          <div class="right-item"><span class="check-icon">✓</span> You have read and understood these Terms of Service</div>
          <div class="right-item"><span class="check-icon">✓</span> KoFund is a record-keeping tool only — not a payment app</div>
          <div class="right-item"><span class="check-icon">✓</span> We do not handle, process, or store real money</div>
          <div class="right-item"><span class="check-icon">✓</span> You are responsible for the accuracy of data you enter</div>
          <div class="right-item"><span class="check-icon">✓</span> Use of KoFund is entirely at your own risk</div>
        </div>
      </div>

      <div class="footer">
        <p>Version 2.0 • KoFund Terms of Service</p>
        <p style="margin-top: 4px; font-size: 11px;">Last updated: June 2026 • © 2026 KoFund. All rights reserved.</p>
      </div>
    </div>
  </body>
  </html>
  `;
}

// ==================== SHARED CSS HELPER ====================
function _getPublicPageCss() {
  return `
    :root {
      --primary: #00C6A2;
      --primary-dark: #00A888;
      --bg: #F8FAFC;
      --card: #FFFFFF;
      --text: #1E293B;
      --text-sec: #64748B;
      --success: #10B981;
      --danger: #EF4444;
      --warning: #F59E0B;
      --border: #E2E8F0;
      --shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
    }
    * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    body { font-family: 'Outfit', sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; padding-top: 80px; padding-bottom: 40px; }
    .top-app-bar { position: fixed; top: 0; left: 0; right: 0; height: 60px; background: var(--primary); z-index: 1001; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
    .app-title-container { display: flex; align-items: center; }
    .app-logo { width: 30px; height: 30px; margin-right: 10px; }
    .app-title { font-size: 20px; font-weight: 800; color: white; letter-spacing: -0.5px; }
    .container { max-width: 800px; margin: 0 auto; padding: 0 20px; }
    .header-card { background: white; padding: 30px; border-radius: 24px; border: 1px solid var(--border); box-shadow: var(--shadow); text-align: center; margin-bottom: 24px; }
    .icon-container { width: 64px; height: 64px; background: rgba(0, 198, 162, 0.1); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; color: var(--primary); }
    .header-card h1 { font-size: 26px; font-weight: 800; margin-bottom: 8px; color: var(--text); }
    .effective-badge { display: inline-block; padding: 6px 16px; background: rgba(0, 198, 162, 0.1); color: var(--primary); border-radius: 20px; border: 1px solid rgba(0, 198, 162, 0.3); font-size: 13px; font-weight: 600; margin-bottom: 12px; }
    .tagline { color: var(--text-sec); font-size: 14px; }
    .section-card { background: white; border-radius: 16px; padding: 24px; border: 1px solid var(--border); margin-bottom: 20px; }
    .section-title { font-size: 18px; font-weight: 700; color: var(--text); margin-bottom: 12px; border-bottom: 2px solid #F1F5F9; padding-bottom: 8px; }
    .section-content { color: var(--text-sec); font-size: 14px; line-height: 1.7; }
    .contact-card { background: white; border-radius: 16px; padding: 20px; border: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; text-decoration: none; color: inherit; transition: border-color 0.2s, box-shadow 0.2s; margin-bottom: 20px; }
    .contact-card:hover { border-color: var(--primary); box-shadow: 0 4px 12px rgba(0,198,162,0.12); }
    .contact-info { display: flex; align-items: center; gap: 14px; }
    .contact-icon { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; }
    .contact-details h4 { font-size: 15px; font-weight: 700; }
    .contact-details p { font-size: 13.5px; color: var(--primary); }
    .arrow-icon { color: var(--text-sec); }
    .footer { text-align: center; font-size: 12px; color: var(--text-sec); padding-top: 20px; border-top: 1px solid var(--border); margin-top: 10px; }
  `;
}

function _getAppBarHtml() {
  return `
    <div class="top-app-bar">
      <div class="app-title-container">
        <div class="app-logo">
          <svg viewBox="0 0 96 90.59"><polygon points="89.84 0 23.76 66.63 0 90.59 0 15.9 23.76 15.9 23.76 47.01 89.84 0" style="fill: #052224;"/><polygon points="84.66 90.59 52.18 90.59 31.7 69.71 48.04 53.24 84.66 90.59" style="fill: #fff;"/><polygon points="96 4.88 67.69 60.18 54.5 46.73 96 4.88" style="fill: #fff;"/></svg>
        </div>
        <div class="app-title">KoFund</div>
      </div>
    </div>
  `;
}

// ==================== SUPPORT PAGE ====================
function getSupportHtml() {
  return `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Support | KoFund</title>
    <meta name="description" content="KoFund Support — get help, find answers to FAQs, and contact our support team.">
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
      ${_getPublicPageCss()}
      .faq-item { border-bottom: 1px solid var(--border); }
      .faq-item:last-child { border-bottom: none; }
      .faq-question { width: 100%; background: none; border: none; text-align: left; padding: 16px 0; font-family: 'Outfit', sans-serif; font-size: 15px; font-weight: 600; color: var(--text); cursor: pointer; display: flex; justify-content: space-between; align-items: center; gap: 12px; }
      .faq-answer { font-size: 14px; color: var(--text-sec); line-height: 1.7; max-height: 0; overflow: hidden; transition: max-height 0.3s ease, padding 0.3s ease; }
      .faq-answer.open { max-height: 300px; padding-bottom: 16px; }
      .faq-chevron { flex-shrink: 0; transition: transform 0.3s ease; color: var(--primary); }
      .faq-chevron.open { transform: rotate(180deg); }
      .support-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 20px; }
      @media (max-width: 480px) { .support-grid { grid-template-columns: 1fr; } }
      .support-tile { background: white; border-radius: 16px; padding: 20px; border: 1px solid var(--border); text-align: center; text-decoration: none; color: var(--text); transition: all 0.2s; display: flex; flex-direction: column; align-items: center; gap: 10px; }
      .support-tile:hover { border-color: var(--primary); box-shadow: 0 4px 12px rgba(0,198,162,0.12); transform: translateY(-2px); }
      .tile-icon { width: 48px; height: 48px; border-radius: 14px; display: flex; align-items: center; justify-content: center; }
      .tile-title { font-size: 14px; font-weight: 700; }
      .tile-sub { font-size: 12px; color: var(--text-sec); }
    </style>
  </head>
  <body>
    ${_getAppBarHtml()}
    <div class="container">
      <div class="header-card">
        <div class="icon-container">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
        </div>
        <h1>Help &amp; Support</h1>
        <div class="effective-badge">We're here to help</div>
        <p class="tagline">Find answers to common questions or reach out to our support team.</p>
      </div>

      <!-- Quick Contact Grid -->
      <div class="support-grid">
        <a href="mailto:kofundapp@gmail.com?subject=KoFund%20Support" class="support-tile">
          <div class="tile-icon" style="background: rgba(16,185,129,0.1); color: #10b981;">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
          </div>
          <div class="tile-title">Email Support</div>
          <div class="tile-sub">kofundapp@gmail.com</div>
        </a>
        <a href="/deleteAccount" class="support-tile">
          <div class="tile-icon" style="background: rgba(239,68,68,0.1); color: #ef4444;">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
          </div>
          <div class="tile-title">Delete Account</div>
          <div class="tile-sub">Remove your data</div>
        </a>
        <a href="/privacyPolicy" class="support-tile">
          <div class="tile-icon" style="background: rgba(0,198,162,0.1); color: var(--primary);">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
          </div>
          <div class="tile-title">Privacy Policy</div>
          <div class="tile-sub">How we use your data</div>
        </a>
        <a href="/termsOfService" class="support-tile">
          <div class="tile-icon" style="background: rgba(59,130,246,0.1); color: #3b82f6;">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/><polyline points="14 2 14 8 20 8"/></svg>
          </div>
          <div class="tile-title">Terms of Service</div>
          <div class="tile-sub">Usage rules &amp; policies</div>
        </a>
      </div>

      <!-- FAQ -->
      <div class="section-card">
        <h2 class="section-title">Frequently Asked Questions</h2>
        <div id="faq-list">
          <div class="faq-item">
            <button class="faq-question" onclick="toggleFaq(this)">
              What is KoFund?
              <svg class="faq-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </button>
            <div class="faq-answer">KoFund is a community fund tracking app that helps groups record contributions and expenses for shared activities like trips, tournaments, club events, and more. KoFund is a record-keeping tool only — we do not handle or process actual money.</div>
          </div>
          <div class="faq-item">
            <button class="faq-question" onclick="toggleFaq(this)">
              How do I join a community?
              <svg class="faq-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </button>
            <div class="faq-answer">You can join a community by entering an invite code provided by your community administrator inside the KoFund app. You can also scan a QR code or open an invite link shared by your admin.</div>
          </div>
          <div class="faq-item">
            <button class="faq-question" onclick="toggleFaq(this)">
              How do I delete my account?
              <svg class="faq-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </button>
            <div class="faq-answer">You can request account deletion through Settings → Delete Account in the app, or by visiting our Delete Account page. This will remove your personal profile data (name, email, tokens) from our system. Note that historical contribution records in shared groups may remain for transparency.</div>
          </div>
          <div class="faq-item">
            <button class="faq-question" onclick="toggleFaq(this)">
              Why am I not receiving notifications?
              <svg class="faq-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </button>
            <div class="faq-answer">Check that:
• Notifications are enabled for KoFund in your device Settings
• You are a member of an approved community
• Your community administrator has enabled notifications
• Try logging out and back in to re-register your notification token.</div>
          </div>
          <div class="faq-item">
            <button class="faq-question" onclick="toggleFaq(this)">
              Is KoFund free to use?
              <svg class="faq-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </button>
            <div class="faq-answer">Yes! KoFund is completely free to use for individuals and community groups. There are no subscription fees or hidden charges.</div>
          </div>
          <div class="faq-item">
            <button class="faq-question" onclick="toggleFaq(this)">
              Who can see my data?
              <svg class="faq-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </button>
            <div class="faq-answer">Your contribution and expense data is only visible to members within your community group. KoFund never sells or shares your personal data with third parties for marketing purposes.</div>
          </div>
        </div>
      </div>

      <!-- Contact -->
      <div class="section-card">
        <h2 class="section-title">Contact Support</h2>
        <div class="section-content" style="margin-bottom: 16px;">Our support team typically responds within 24–48 business hours.</div>
        <a href="mailto:kofundapp@gmail.com?subject=KoFund%20Support%20Request" class="contact-card" style="margin-bottom: 0;">
          <div class="contact-info">
            <div class="contact-icon" style="background: rgba(16,185,129,0.1); color: #10b981;">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
            </div>
            <div class="contact-details">
              <h4>Email Support</h4>
              <p>kofundapp@gmail.com</p>
            </div>
          </div>
          <div class="arrow-icon"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m9 18 6-6-6-6"/></svg></div>
        </a>
      </div>

      <div class="footer">
        <p>KoFund Support • © 2026 KoFund. All rights reserved.</p>
      </div>
    </div>
    <script>
      function toggleFaq(btn) {
        const answer = btn.nextElementSibling;
        const chevron = btn.querySelector('.faq-chevron');
        answer.classList.toggle('open');
        chevron.classList.toggle('open');
      }
    </script>
  </body>
  </html>
  `;
}

// ==================== DATA SAFETY PAGE ====================
function getDataSafetyHtml() {
  return `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Data Safety | KoFund</title>
    <meta name="description" content="KoFund Data Safety — understand what data we collect, share, and how we protect it.">
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
      ${_getPublicPageCss()}
      .safety-row { display: flex; align-items: flex-start; gap: 14px; padding: 14px 0; border-bottom: 1px solid #F1F5F9; }
      .safety-row:last-child { border-bottom: none; }
      .safety-icon { width: 36px; height: 36px; border-radius: 10px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
      .safety-label { font-size: 14px; font-weight: 600; color: var(--text); }
      .safety-desc { font-size: 13px; color: var(--text-sec); margin-top: 2px; }
      .badge { display: inline-block; padding: 3px 10px; border-radius: 20px; font-size: 11px; font-weight: 700; margin-top: 4px; }
      .badge-yes { background: rgba(16,185,129,0.12); color: #059669; }
      .badge-no { background: rgba(239,68,68,0.12); color: #dc2626; }
      .badge-optional { background: rgba(245,158,11,0.12); color: #d97706; }
      .summary-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px; margin-bottom: 20px; }
      @media (max-width: 480px) { .summary-grid { grid-template-columns: 1fr; } }
      .summary-tile { background: white; border-radius: 16px; padding: 18px; border: 1px solid var(--border); text-align: center; }
      .summary-tile .s-icon { font-size: 28px; margin-bottom: 8px; }
      .summary-tile .s-title { font-size: 13px; font-weight: 700; }
      .summary-tile .s-desc { font-size: 11px; color: var(--text-sec); margin-top: 4px; }
    </style>
  </head>
  <body>
    ${_getAppBarHtml()}
    <div class="container">
      <div class="header-card">
        <div class="icon-container">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
        </div>
        <h1>Data Safety</h1>
        <div class="effective-badge">Transparency Report</div>
        <p class="tagline">We believe in full transparency about the data we collect and how we use it.</p>
      </div>

      <!-- Summary tiles -->
      <div class="summary-grid">
        <div class="summary-tile">
          <div class="s-icon">🔒</div>
          <div class="s-title">Encrypted</div>
          <div class="s-desc">All data in transit and at rest</div>
        </div>
        <div class="summary-tile">
          <div class="s-icon">🚫</div>
          <div class="s-title">Not Sold</div>
          <div class="s-desc">We never sell your personal data</div>
        </div>
        <div class="summary-tile">
          <div class="s-icon">🗑️</div>
          <div class="s-title">Deletable</div>
          <div class="s-desc">Request account deletion anytime</div>
        </div>
      </div>

      <!-- Data Collected -->
      <div class="section-card">
        <h2 class="section-title">Data We Collect</h2>
        <div class="safety-row">
          <div class="safety-icon" style="background: rgba(0,198,162,0.1); color: var(--primary);">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
          </div>
          <div>
            <div class="safety-label">Name &amp; Email Address</div>
            <div class="safety-desc">Used for account creation, authentication, and notifications</div>
            <span class="badge badge-yes">Collected</span>
          </div>
        </div>
        <div class="safety-row">
          <div class="safety-icon" style="background: rgba(59,130,246,0.1); color: #3b82f6;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
          </div>
          <div>
            <div class="safety-label">Device &amp; App Info</div>
            <div class="safety-desc">Device type, OS version, crash logs for performance improvement</div>
            <span class="badge badge-yes">Collected</span>
          </div>
        </div>
        <div class="safety-row">
          <div class="safety-icon" style="background: rgba(245,158,11,0.1); color: #f59e0b;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/></svg>
          </div>
          <div>
            <div class="safety-label">Contribution &amp; Expense Records</div>
            <div class="safety-desc">Data entered by community administrators — visible to group members only</div>
            <span class="badge badge-yes">Collected</span>
          </div>
        </div>
        <div class="safety-row">
          <div class="safety-icon" style="background: rgba(239,68,68,0.1); color: #ef4444;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
          </div>
          <div>
            <div class="safety-label">Banking &amp; Payment Data</div>
            <div class="safety-desc">We do NOT collect card numbers, UPI IDs, bank details, or payment credentials of any kind</div>
            <span class="badge badge-no">Not Collected</span>
          </div>
        </div>
        <div class="safety-row">
          <div class="safety-icon" style="background: rgba(239,68,68,0.1); color: #ef4444;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
          </div>
          <div>
            <div class="safety-label">Precise Location</div>
            <div class="safety-desc">We do not track or collect your GPS location</div>
            <span class="badge badge-no">Not Collected</span>
          </div>
        </div>
      </div>

      <!-- Data Sharing -->
      <div class="section-card">
        <h2 class="section-title">Data Sharing</h2>
        <div class="safety-row">
          <div class="safety-icon" style="background: rgba(239,68,68,0.1); color: #ef4444;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></svg>
          </div>
          <div>
            <div class="safety-label">Sold to Third Parties</div>
            <div class="safety-desc">Your personal data is never sold to advertisers or third parties</div>
            <span class="badge badge-no">Never</span>
          </div>
        </div>
        <div class="safety-row">
          <div class="safety-icon" style="background: rgba(0,198,162,0.1); color: var(--primary);">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          </div>
          <div>
            <div class="safety-label">Shared with Community Members</div>
            <div class="safety-desc">Contribution and expense records are visible to members within the same community group</div>
            <span class="badge badge-yes">Yes (within group)</span>
          </div>
        </div>
        <div class="safety-row">
          <div class="safety-icon" style="background: rgba(59,130,246,0.1); color: #3b82f6;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.93a2 2 0 0 1-1.66-.9l-.82-1.2A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13c0 1.1.9 2 2 2Z"/></svg>
          </div>
          <div>
            <div class="safety-label">Firebase / Google Services</div>
            <div class="safety-desc">We use Google Firebase for authentication, database, and push notifications — governed by Google's Privacy Policy</div>
            <span class="badge badge-optional">Infrastructure only</span>
          </div>
        </div>
      </div>

      <!-- Security -->
      <div class="section-card">
        <h2 class="section-title">Security Practices</h2>
        <div class="section-content">
          <div class="safety-row" style="padding-top: 0;">
            <div class="safety-icon" style="background: rgba(0,198,162,0.1); color: var(--primary);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg></div>
            <div><div class="safety-label">HTTPS Encryption</div><div class="safety-desc">All data transfers are secured with TLS/HTTPS encryption</div></div>
          </div>
          <div class="safety-row">
            <div class="safety-icon" style="background: rgba(0,198,162,0.1); color: var(--primary);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg></div>
            <div><div class="safety-label">Firestore Security Rules</div><div class="safety-desc">Access control rules ensure only authorized users can read/write their community's data</div></div>
          </div>
          <div class="safety-row">
            <div class="safety-icon" style="background: rgba(0,198,162,0.1); color: var(--primary);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></div>
            <div><div class="safety-label">Firebase Authentication</div><div class="safety-desc">Secure account management using Google's Firebase Authentication service</div></div>
          </div>
        </div>
      </div>

      <div class="footer">
        <p>KoFund Data Safety Report • © 2026 KoFund. All rights reserved.</p>
        <p style="margin-top: 4px;"><a href="/privacyPolicy" style="color: var(--primary); text-decoration: none;">View Full Privacy Policy →</a></p>
      </div>
    </div>
  </body>
  </html>
  `;
}

// ==================== ABOUT PAGE ====================
function getAboutHtml() {
  return `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>About KoFund</title>
    <meta name="description" content="About KoFund — the community fund tracking app that makes group finance simple and transparent.">
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
      ${_getPublicPageCss()}
      .hero-banner { background: #052224; border-radius: 24px; padding: 36px 24px; text-align: center; margin-bottom: 20px; color: white; border: 1px solid rgba(255,255,255,0.1); }
      .hero-logo { width: 64px; height: 64px; margin: 0 auto 16px; }
      .hero-banner h1 { font-size: 32px; font-weight: 800; letter-spacing: -1px; }
      .hero-banner p { font-size: 15px; opacity: 0.85; margin-top: 8px; }
      .feature-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 20px; }
      @media (max-width: 480px) { .feature-grid { grid-template-columns: 1fr; } }
      .feature-tile { background: white; border-radius: 16px; padding: 20px; border: 1px solid var(--border); }
      .feature-tile .f-icon { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; margin-bottom: 12px; }
      .feature-tile h3 { font-size: 15px; font-weight: 700; margin-bottom: 6px; }
      .feature-tile p { font-size: 13px; color: var(--text-sec); line-height: 1.6; }
      .version-chip { display: inline-flex; align-items: center; gap: 6px; background: rgba(0,198,162,0.1); border: 1px solid rgba(0,198,162,0.3); border-radius: 20px; padding: 6px 14px; font-size: 13px; font-weight: 600; color: var(--primary); }
    </style>
  </head>
  <body>
    ${_getAppBarHtml()}
    <div class="container">
      <!-- Hero -->
      <div class="hero-banner">
        <div class="hero-logo">
          <svg viewBox="0 0 96 90.59" xmlns="http://www.w3.org/2000/svg">
            <polygon points="89.84 0 23.76 66.63 0 90.59 0 15.9 23.76 15.9 23.76 47.01 89.84 0" style="fill: #052224;"/>
            <polygon points="84.66 90.59 52.18 90.59 31.7 69.71 48.04 53.24 84.66 90.59" style="fill: #fff;"/>
            <polygon points="96 4.88 67.69 60.18 54.5 46.73 96 4.88" style="fill: #fff;"/>
          </svg>
        </div>
        <h1>KoFund</h1>
        <p>Community Fund Tracking — Simple, Transparent, Powerful</p>
      </div>

      <!-- About Card -->
      <div class="section-card">
        <h2 class="section-title">What is KoFund?</h2>
        <div class="section-content">KoFund is a community fund management app designed to bring transparency and organization to group finances. Whether you're managing a sports club, a travel group, a school community, or any other team — KoFund helps everyone stay on the same page.

KoFund is a record-keeping tool. We help you track who has contributed, how funds have been spent, and what the current balance is — all in one place, accessible to all members.

We do not process, hold, or transfer actual money. All financial transactions happen directly between community members.</div>
      </div>

      <!-- Feature Grid -->
      <div class="feature-grid">
        <div class="feature-tile">
          <div class="f-icon" style="background: rgba(0,198,162,0.1); color: var(--primary);">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          </div>
          <h3>Community Groups</h3>
          <p>Organize members into communities with admin and member roles.</p>
        </div>
        <div class="feature-tile">
          <div class="f-icon" style="background: rgba(59,130,246,0.1); color: #3b82f6;">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          </div>
          <h3>Contribution Tracking</h3>
          <p>Record and track who has paid and how much in real time.</p>
        </div>
        <div class="feature-tile">
          <div class="f-icon" style="background: rgba(239,68,68,0.1); color: #ef4444;">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12V7H5a2 2 0 0 1 0-4h14v4"/><path d="M3 5v14a2 2 0 0 0 2 2h16v-5"/><path d="M18 12a2 2 0 0 0 0 4h4v-4Z"/></svg>
          </div>
          <h3>Expense Management</h3>
          <p>Log expenses and keep a transparent record of how funds are spent.</p>
        </div>
        <div class="feature-tile">
          <div class="f-icon" style="background: rgba(245,158,11,0.1); color: #f59e0b;">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/></svg>
          </div>
          <h3>Event Management</h3>
          <p>Create events, share public links, and manage participation.</p>
        </div>
        <div class="feature-tile">
          <div class="f-icon" style="background: rgba(16,185,129,0.1); color: #10b981;">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 20V10"/><path d="M12 20V4"/><path d="M6 20v-6"/></svg>
          </div>
          <h3>Real-Time Analytics</h3>
          <p>Visual summaries of balances, payments, and outstanding dues.</p>
        </div>
        <div class="feature-tile">
          <div class="f-icon" style="background: rgba(139,92,246,0.1); color: #8b5cf6;">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
          </div>
          <h3>Smart Notifications</h3>
          <p>Automated contribution reminders and community announcements.</p>
        </div>
      </div>

      <!-- Version Info -->
      <div class="section-card">
        <h2 class="section-title">App Information</h2>
        <div style="display: flex; flex-direction: column; gap: 12px;">
          <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 0; border-bottom: 1px solid #F1F5F9;">
            <span style="font-size: 14px; color: var(--text-sec);">App Name</span>
            <span style="font-size: 14px; font-weight: 700;">KoFund</span>
          </div>
          <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 0; border-bottom: 1px solid #F1F5F9;">
            <span style="font-size: 14px; color: var(--text-sec);">Platform</span>
            <span style="font-size: 14px; font-weight: 700;">Android &amp; iOS (Flutter)</span>
          </div>
          <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 0; border-bottom: 1px solid #F1F5F9;">
            <span style="font-size: 14px; color: var(--text-sec);">Backend</span>
            <span style="font-size: 14px; font-weight: 700;">Firebase (Google Cloud)</span>
          </div>
          <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 0;">
            <span style="font-size: 14px; color: var(--text-sec);">Contact</span>
            <a href="mailto:kofundapp@gmail.com" style="font-size: 14px; font-weight: 700; color: var(--primary); text-decoration: none;">kofundapp@gmail.com</a>
          </div>
        </div>
      </div>

      <div class="footer">
        <p>© 2026 KoFund. All rights reserved.</p>
        <p style="margin-top: 6px;">
          <a href="/privacyPolicy" style="color: var(--primary); text-decoration: none; margin: 0 8px;">Privacy Policy</a> •
          <a href="/termsOfService" style="color: var(--primary); text-decoration: none; margin: 0 8px;">Terms of Service</a> •
          <a href="/support" style="color: var(--primary); text-decoration: none; margin: 0 8px;">Support</a>
        </p>
      </div>
    </div>
  </body>
  </html>
  `;
}

// ==================== DELETE ACCOUNT PAGE ====================
// This page lets users request deletion of their documents from the users collection.
// It does NOT delete the Firebase Auth user — only the Firestore documents.
function getDeleteAccountHtml(baseUrl) {
  const apiUrl = baseUrl ? `${baseUrl}/deleteAccountData` : '/deleteAccountData';
  return `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Delete Account Data | KoFund</title>
    <meta name="description" content="Request deletion of your KoFund account data from our systems.">
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
      ${_getPublicPageCss()}
      body { padding-top: 80px; }
      .danger-header { background: linear-gradient(135deg, #fef2f2 0%, #fff5f5 100%); border: 1.5px solid #fecaca; border-radius: 24px; padding: 30px; text-align: center; margin-bottom: 24px; }
      .danger-icon { width: 72px; height: 72px; background: rgba(239,68,68,0.1); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; color: var(--danger); }
      .danger-header h1 { font-size: 26px; font-weight: 800; color: #dc2626; margin-bottom: 8px; }
      .danger-header p { font-size: 14px; color: #7f1d1d; line-height: 1.6; }
      .warning-box { background: #fffbeb; border: 1.5px solid #fde68a; border-radius: 16px; padding: 18px; margin-bottom: 24px; display: flex; gap: 12px; align-items: flex-start; }
      .warning-box .w-icon { color: #d97706; flex-shrink: 0; margin-top: 2px; }
      .warning-box .w-text { font-size: 13.5px; color: #78350f; line-height: 1.6; }
      .warning-box .w-title { font-weight: 700; font-size: 14px; color: #92400e; margin-bottom: 4px; }
      .form-card { background: white; border-radius: 20px; padding: 28px; border: 1px solid var(--border); margin-bottom: 20px; box-shadow: var(--shadow); }
      .form-group { margin-bottom: 20px; }
      .form-label { display: block; font-size: 14px; font-weight: 600; color: var(--text); margin-bottom: 8px; }
      .form-input { width: 100%; padding: 14px 16px; border: 1.5px solid var(--border); border-radius: 12px; font-family: 'Outfit', sans-serif; font-size: 15px; color: var(--text); background: var(--bg); outline: none; transition: border-color 0.2s; box-sizing: border-box; }
      .form-input:focus { border-color: #ef4444; background: white; }
      .form-hint { font-size: 12px; color: var(--text-sec); margin-top: 6px; }
      .confirm-row { display: flex; align-items: flex-start; gap: 10px; margin-bottom: 24px; }
      .confirm-row input[type="checkbox"] { width: 18px; height: 18px; margin-top: 2px; accent-color: #ef4444; flex-shrink: 0; }
      .confirm-row label { font-size: 13.5px; color: var(--text-sec); line-height: 1.5; }
      .delete-btn { width: 100%; padding: 16px; background: #ef4444; color: white; border: none; border-radius: 14px; font-family: 'Outfit', sans-serif; font-size: 16px; font-weight: 700; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; justify-content: center; gap: 8px; }
      .delete-btn:hover:not(:disabled) { background: #dc2626; transform: translateY(-1px); box-shadow: 0 6px 16px rgba(239,68,68,0.3); }
      .delete-btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
      .success-state { display: none; text-align: center; padding: 30px 20px; }
      .success-icon { width: 72px; height: 72px; background: rgba(16,185,129,0.1); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; color: #10b981; }
      .success-state h2 { font-size: 22px; font-weight: 800; color: var(--text); margin-bottom: 8px; }
      .success-state p { font-size: 14px; color: var(--text-sec); line-height: 1.6; }
      .error-msg { background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px; padding: 12px 16px; font-size: 13px; color: #dc2626; margin-bottom: 16px; display: none; }
      .spinner { width: 20px; height: 20px; border: 2px solid rgba(255,255,255,0.3); border-top: 2px solid white; border-radius: 50%; animation: spin 0.8s linear infinite; }
      @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
      .what-gets-deleted { background: var(--bg); border-radius: 12px; padding: 16px; border: 1px solid var(--border); margin-bottom: 20px; }
      .del-item { display: flex; align-items: center; gap: 10px; padding: 8px 0; font-size: 13px; color: var(--text-sec); border-bottom: 1px solid #F1F5F9; }
      .del-item:last-child { border-bottom: none; }
      .del-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
    </style>
  </head>
  <body>
    ${_getAppBarHtml()}
    <div class="container">

      <!-- Header -->
      <div class="danger-header">
        <div class="danger-icon">
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/></svg>
        </div>
        <h1>Delete Account Data</h1>
        <p>This action will permanently remove your personal profile data from KoFund's database. This cannot be undone.</p>
      </div>

      <!-- Warning -->
      <div class="warning-box">
        <div class="w-icon">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
        </div>
        <div>
          <div class="w-title">Important: What this does</div>
          <div class="w-text">This removes your personal data (name, email, FCM tokens, profile info) from our users database. Historical contribution records in shared community groups may remain for transparency. Your Firebase Authentication account is separate — contact support to fully delete your login account.</div>
        </div>
      </div>

      <!-- What gets deleted -->
      <div class="section-card">
        <h2 class="section-title">What gets removed</h2>
        <div class="what-gets-deleted">
          <div class="del-item"><div class="del-dot" style="background: #ef4444;"></div>Your profile (name, email address, phone number)</div>
          <div class="del-item"><div class="del-dot" style="background: #ef4444;"></div>Push notification tokens (FCM tokens)</div>
          <div class="del-item"><div class="del-dot" style="background: #ef4444;"></div>In-app notification history</div>
          <div class="del-item"><div class="del-dot" style="background: #ef4444;"></div>Community membership info &amp; approval status</div>
          <div class="del-item"><div class="del-dot" style="background: #f59e0b;"></div><span><b>Not removed:</b> Historical contributions &amp; expenses in shared community groups (for transparency)</span></div>
          <div class="del-item"><div class="del-dot" style="background: #f59e0b;"></div><span><b>Not removed:</b> Firebase Authentication account (contact support for full account deletion)</span></div>
        </div>
      </div>

      <!-- Form Card -->
      <div class="form-card">
        <div id="form-state">
          <h2 class="section-title" style="border: none; padding: 0; margin-bottom: 20px;">Request Data Deletion</h2>
          <div id="error-msg" class="error-msg"></div>

          <div class="form-group">
            <label class="form-label" for="email-input">Registered Email Address</label>
            <input type="email" id="email-input" class="form-input" placeholder="your@email.com" autocomplete="email">
            <div class="form-hint">Enter the email address associated with your KoFund account</div>
          </div>

          <div class="form-group">
            <label class="form-label" for="uid-input">User ID (optional)</label>
            <input type="text" id="uid-input" class="form-input" placeholder="Found in app: Settings → Account Info">
            <div class="form-hint">Your Firebase User ID helps us locate your account faster. Find it in the app under Settings.</div>
          </div>

          <div class="confirm-row">
            <input type="checkbox" id="confirm-checkbox">
            <label for="confirm-checkbox">I understand this action is permanent and cannot be undone. I confirm I want to delete my personal data from KoFund.</label>
          </div>

          <button class="delete-btn" id="delete-btn" onclick="submitDeletion()" disabled>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
            Delete My Account Data
          </button>
        </div>

        <div class="success-state" id="success-state">
          <div class="success-icon">
            <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
          </div>
          <h2>Deletion Request Submitted</h2>
          <p>Your account data has been queued for deletion. You will receive a confirmation email (if available) within 24 hours.</p>
          <p style="margin-top: 12px; font-size: 12px;">For complete account deletion including Firebase Authentication, please email us at <a href="mailto:kofundapp@gmail.com" style="color: var(--primary);">kofundapp@gmail.com</a>.</p>
        </div>
      </div>

      <!-- Alternative -->
      <div class="section-card">
        <h2 class="section-title">Need more help?</h2>
        <div class="section-content" style="margin-bottom: 14px;">For complete account deletion (including Firebase Authentication login), or if you encounter any issues, please contact our support team directly.</div>
        <a href="mailto:kofundapp@gmail.com?subject=Account%20Deletion%20Request" class="contact-card" style="margin-bottom: 0;">
          <div class="contact-info">
            <div class="contact-icon" style="background: rgba(239,68,68,0.1); color: #ef4444;">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
            </div>
            <div class="contact-details">
              <h4>Contact Support for Full Deletion</h4>
              <p>kofundapp@gmail.com</p>
            </div>
          </div>
          <div class="arrow-icon"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m9 18 6-6-6-6"/></svg></div>
        </a>
      </div>

      <div class="footer">
        <p>KoFund • <a href="/privacyPolicy" style="color: var(--primary); text-decoration: none;">Privacy Policy</a> • © 2026 KoFund</p>
      </div>
    </div>

    <script>
      const checkbox = document.getElementById('confirm-checkbox');
      const deleteBtn = document.getElementById('delete-btn');
      checkbox.addEventListener('change', () => {
        deleteBtn.disabled = !checkbox.checked;
      });

      async function submitDeletion() {
        const email = document.getElementById('email-input').value.trim();
        const uid = document.getElementById('uid-input').value.trim();
        const errorMsg = document.getElementById('error-msg');

        if (!email) {
          errorMsg.textContent = 'Please enter your email address.';
          errorMsg.style.display = 'block';
          return;
        }
        if (!/^[^@]+@[^@]+\.[^@]+$/.test(email)) {
          errorMsg.textContent = 'Please enter a valid email address.';
          errorMsg.style.display = 'block';
          return;
        }
        errorMsg.style.display = 'none';

        deleteBtn.disabled = true;
        deleteBtn.innerHTML = '<div class="spinner"></div> Processing...';

        try {
          const resp = await fetch('${apiUrl}', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, uid: uid || null })
          });
          const data = await resp.json();

          if (resp.ok && data.success) {
            document.getElementById('form-state').style.display = 'none';
            document.getElementById('success-state').style.display = 'block';
          } else {
            errorMsg.textContent = data.error || 'Something went wrong. Please try again or contact support.';
            errorMsg.style.display = 'block';
            deleteBtn.disabled = false;
            deleteBtn.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg> Delete My Account Data';
          }
        } catch (e) {
          errorMsg.textContent = 'Network error. Please check your connection and try again.';
          errorMsg.style.display = 'block';
          deleteBtn.disabled = false;
          deleteBtn.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg> Delete My Account Data';
        }
      }
    </script>
  </body>
  </html>
  `;
}

module.exports = { 
  getEventHtml, 
  getPrivateEventHtml,
  getPrivacyPolicyHtml,
  getTermsOfServiceHtml,
  getSupportHtml,
  getDataSafetyHtml,
  getAboutHtml,
  getDeleteAccountHtml,
};

