importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

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
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
