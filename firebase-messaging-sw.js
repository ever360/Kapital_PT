importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAaxzlRP7giXc0WMYsrXYKDpakx-L2-JHI',
  appId: '1:903185337094:web:98058680bf7d8c6f98ec87',
  messagingSenderId: '903185337094',
  projectId: 'kapital-br',
  authDomain: 'kapital-br.firebaseapp.com',
  storageBucket: 'kapital-br.firebasestorage.app',
  measurementId: 'G-J4SN2H8BJG',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const title = payload?.notification?.title || 'Kapital';
  const options = {
    body: payload?.notification?.body || 'Tienes una nueva notificacion.',
    icon: '/icons/kapital_192.png',
  };

  self.registration.showNotification(title, options);
});
