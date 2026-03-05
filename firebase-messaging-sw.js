importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config object.
// https://firebase.google.com/docs/web/setup#config-object
firebase.initializeApp({
    apiKey: 'AIzaSyAaxzlRP7giXc0WMYsrXYKDpakx-L2-JHI',
    appId: '1:903185337094:web:98058680bf7d8c6f98ec87',
    messagingSenderId: '903185337094',
    projectId: 'kapital-br',
    authDomain: 'kapital-br.firebaseapp.com',
    storageBucket: 'kapital-br.firebasestorage.app',
    measurementId: 'G-J4SN2H8BJG'
});

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    // Customize notification here
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
