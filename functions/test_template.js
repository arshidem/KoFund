const templates = require('./templates');
try {
  let html = templates.getEventHtml({
    event: { collectedAmount: 100, totalExpenses: 20 },
    participants: [],
    contributions: [],
    expenses: [],
    title: 'Test',
    date: 'Date',
    icon: 'football',
    eventId: '123',
    downloadUrl: 'url',
    appWebLink: 'url',
    selectedMonth: 'all',
    password: 'pwd'
  });
  console.log("SUCCESS");
} catch(e) {
  console.error("ERROR:", e);
}
