importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: 'AIzaSyC054u7UoGzDZkIgK8pV6alDmqpUf5YuJg',
  appId: '1:435502718618:web:70ca6ecfc03c9763090923',
  messagingSenderId: '435502718618',
  projectId: 'vervestride-app',
  authDomain: 'vervestride-app.firebaseapp.com',
  storageBucket: 'vervestride-app.firebasestorage.app',
  measurementId: 'G-60BHKBBHVV',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'VerveStride';
  const options = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(title, options);
});
