// web/firebase-messaging-sw.js

// Import Firebase scripts for service worker
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

// Your Firebase config (from Firebase Console)
firebase.initializeApp({
  apiKey: 'AIzaSyBBgRegrFPDpsYi_-P_mM-fMnzdGywsuJo',
  authDomain: 'kofund-153ba.firebaseapp.com',
  projectId: 'kofund-153ba',
  storageBucket: 'kofund-153ba.firebasestorage.app',
  messagingSenderId: '136492130886',
  appId: '1:136492130886:web:your-web-app-id', // Replace with your web app ID
});

// Initialize messaging
const messaging = firebase.messaging();

// Background message handler
messaging.onBackgroundMessage((payload) => {
  console.log('📨 Web Background message received:', payload);
  
  const notificationTitle = payload.notification?.title || payload.data?.title || 'Kofund';
  const notificationBody = payload.notification?.body || payload.data?.body || 'You have a new notification';
  
  const notificationOptions = {
    body: notificationBody,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-72.png',
    data: {
      ...payload.data,
      url: payload.data?.deepLink || '/',
      notificationId: payload.data?.notificationId || Date.now().toString(),
    },
    actions: [
      {
        action: 'open',
        title: 'Open App'
      }
    ],
    vibrate: [200, 100, 200],
    requireInteraction: true,
  };
  
  return self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  const data = event.notification.data || {};
  const urlToOpen = data.url || '/';
  
  event.waitUntil(
    clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    }).then((windowClients) => {
      // Check if there's already a window/tab open
      for (const client of windowClients) {
        if (client.url.includes(urlToOpen) && 'focus' in client) {
          return client.focus();
        }
      }
      // If not, open a new window/tab
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});