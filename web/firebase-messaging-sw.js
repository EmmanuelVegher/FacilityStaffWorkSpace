// Give the service worker a name
self.name = 'firebase-messaging-sw';

// Import and configure the Firebase SDK
// Note: This is the global script import, not a module import.
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker with your project's configuration
// IMPORTANT: Replace this with your project's firebaseConfig
const firebaseConfig = {
    apiKey: "AIzaSyAWlypoMsWMrhcxAdNZHlPMIbxJ4BfmCTs",
    authDomain: "attendanceapp-a6853.firebaseapp.com",
    databaseURL: "https://attendanceapp-a6853-default-rtdb.firebaseio.com",
    projectId: "attendanceapp-a6853",
    storageBucket: "attendanceapp-a6853.appspot.com",
    messagingSenderId: "670103320817",
    appId: "1:670103320817:web:03678acef1bcce7fb19150",
    measurementId: "G-K0CS7GT1X7"
};

firebase.initializeApp(firebaseConfig);

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

// Optional: If you want to handle background messages, you can add a handler.
// For simple notifications sent from the server, this is often not needed.
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);

    // Customize the notification here if needed
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/service_delivery.png' // Optional: path to your notification icon
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});