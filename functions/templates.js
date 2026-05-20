/**
 * 🎨 PREMIUM LIGHT MODE TEMPLATE FOR SUPER LINKS
 * Designed to match the KoFund App aesthetic.
 */

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
          <a href="${appWebLink}" class="cta-btn secondary-cta" target="_blank">Web Link</a>
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
    <title>${title} | KoFund</title>
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
      .member-row { display: flex; align-items: center; padding: 16px 0; border-bottom: 1px solid var(--border); }
      .member-avatar { width: 44px; height: 44px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 800; margin-right: 14px; }
      .member-info { flex: 1; }
      .member-name { font-size: 16px; font-weight: 700; }
      .member-amount { font-size: 18px; font-weight: 800; color: var(--primary); }
      .member-due { font-size: 11px; color: var(--text-sec); font-weight: 600; }

      .list-container { background: white; border-radius: 16px; padding: 10px 20px; border: 1px solid var(--border); }
      .list-item { display: flex; align-items: center; padding: 15px 0; border-bottom: 1px solid #F1F5F9; }
      .list-amount { font-weight: 700; color: var(--success); }
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
      <div class="sticky-title">${title}</div>
    </div>

    <div class="header" id="main-header">
      <h1>${title}</h1>
      <div class="event-date" id="event-date-display">${date}</div>
      ${monthSelectorHtml}
    </div>

    <div class="tabs-container">
      <div class="tabs">
        <button class="tab-btn active" id="btn-overview" onclick="showTab('overview')">Overview</button>
        <button class="tab-btn" id="btn-participants" onclick="showTab('participants')">Participants</button>
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
            <div class="header-tile"><div class="tile-label">Participants</div><div class="tile-val highlight">\${event.participantType === 'fixed' ? participants.length + ' / ' + event.maxParticipants : participants.length}</div></div>
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
              <div class="member-avatar" style="background:#00C6A215;color:#00C6A2">\${(p.userName || 'M').charAt(0)}</div>
              <div class="member-info"><div class="member-name">\${p.userName}</div></div>
              <div class="member-amount">₹\${Math.floor(p.contributionPaid || 0)}</div>
            </div>
          \`).join('');
        }

        const es = document.getElementById('expenses');
        if (expenses.length === 0) {
          es.innerHTML = '<div class="empty-state">No expenses yet.</div>';
        } else {
          es.innerHTML = '<div class="list-container">' + expenses.map(e => \`
            <div class="list-item">
              <div class="member-info"><div class="member-name">\${e.title}</div><div class="member-due">\${e.expenseDate ? new Date(e.expenseDate.seconds * 1000).toLocaleDateString() : ''}</div></div>
              <div class="list-amount expense">-₹\${e.amount}</div>
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

      window.onload = init;
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

module.exports = { getEventHtml, getPrivateEventHtml };
