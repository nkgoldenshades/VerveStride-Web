// ═══════════════════════════════════════════════════════════════════════════
// WEB PUSH NOTIFICATION MANAGER - Pure JavaScript
// For VerveStride AI - Client-side web push notifications
// ═══════════════════════════════════════════════════════════════════════════

class WebPushManager {
  constructor() {
    this.messaging = null;
    this.fcmToken = null;
    this.isInitialized = false;
  }

  // Initialize Firebase Messaging
  async initialize() {
    if (this.isInitialized) {
      console.log('✅ WebPushManager already initialized');
      return this.fcmToken;
    }

    try {
      // Check if Firebase is loaded
      if (typeof firebase === 'undefined') {
        throw new Error('Firebase not loaded! Include Firebase SDK in HTML first.');
      }

      // Initialize Firebase Messaging
      this.messaging = firebase.messaging();
      
      console.log('🔔 WebPushManager initialized');
      this.isInitialized = true;

      return await this.requestPermission();
    } catch (error) {
      console.error('❌ Failed to initialize WebPushManager:', error);
      throw error;
    }
  }

  // Request notification permission and get FCM token
  async requestPermission() {
    try {
      // Check if notifications are supported
      if (!('Notification' in window)) {
        throw new Error('This browser does not support notifications');
      }

      // Request permission
      const permission = await Notification.requestPermission();
      
      if (permission === 'granted') {
        console.log('✅ Notification permission granted');
        
        // Get FCM token - VAPID key is optional, Firebase will use default
        try {
          this.fcmToken = await this.messaging.getToken();
        } catch (tokenError) {
          // If default doesn't work, try with explicit VAPID key
          // You can get this from Firebase Console > Project Settings > Cloud Messaging
          console.warn('⚠️ Default token fetch failed, trying with VAPID key...');
          this.fcmToken = await this.messaging.getToken({
            vapidKey: 'BNxrEZDfW8QhZ5L9K6vJ0X8wY7vU9T8sR7qP6oN5mM4lK3jI2hH1gG0fF9eE8dD7cC6bB5aA4'
          });
        }
        
        if (!this.fcmToken) {
          throw new Error('Failed to get FCM token');
        }
        
        console.log('📱 FCM Token obtained');
        
        // Save token to Firestore for sending notifications later
        await this.saveTokenToFirestore(this.fcmToken);
        
        return this.fcmToken;
      } else if (permission === 'denied') {
        console.warn('⚠️ Notification permission denied');
        return null;
      } else {
        console.log('ℹ️ Notification permission dismissed');
        return null;
      }
    } catch (error) {
      console.error('❌ Failed to request permission:', error);
      throw error;
    }
  }

  // Save FCM token to Firestore
  async saveTokenToFirestore(token) {
    try {
      const user = firebase.auth().currentUser;
      if (!user) {
        console.warn('⚠️ No user logged in, skipping token save');
        return;
      }

      await firebase.firestore()
        .collection('users')
        .doc(user.uid)
        .set({
          fcmTokens: firebase.firestore.FieldValue.arrayUnion(token),
          lastTokenUpdate: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

      console.log('✅ FCM token saved to Firestore');
    } catch (error) {
      console.error('❌ Failed to save token to Firestore:', error);
    }
  }

  // Listen for foreground messages
  onMessage(callback) {
    if (!this.messaging) {
      console.error('❌ Messaging not initialized! Call initialize() first.');
      return;
    }

    this.messaging.onMessage((payload) => {
      console.log('📬 Foreground message received:', payload);
      
      // Show notification
      this.showNotification(
        payload.notification?.title || 'VerveStride AI',
        payload.notification?.body || '',
        payload.notification?.icon || '/icons/Icon-192.png',
        payload.data
      );

      // Call custom callback
      if (callback) {
        callback(payload);
      }
    });
  }

  // Show browser notification
  showNotification(title, body, icon, data = {}) {
    if ('Notification' in window && Notification.permission === 'granted') {
      const notification = new Notification(title, {
        body: body,
        icon: icon,
        badge: '/icons/Icon-192.png',
        tag: data.tag || 'vervestride-notification',
        requireInteraction: false,
        data: data
      });

      // Handle notification click
      notification.onclick = (event) => {
        event.preventDefault();
        window.focus();
        notification.close();
        
        // Navigate to specific page if URL provided
        if (data.url) {
          window.location.href = data.url;
        }
      };

      return notification;
    }
  }

  // Get current FCM token
  getToken() {
    return this.fcmToken;
  }

  // Check notification permission status
  getPermissionStatus() {
    if (!('Notification' in window)) {
      return 'unsupported';
    }
    return Notification.permission; // 'granted', 'denied', or 'default'
  }

  // Delete FCM token (unsubscribe)
  async deleteToken() {
    try {
      if (!this.messaging || !this.fcmToken) {
        console.warn('⚠️ No token to delete');
        return;
      }

      await this.messaging.deleteToken();
      
      // Remove from Firestore
      const user = firebase.auth().currentUser;
      if (user) {
        await firebase.firestore()
          .collection('users')
          .doc(user.uid)
          .update({
            fcmTokens: firebase.firestore.FieldValue.arrayRemove(this.fcmToken)
          });
      }

      this.fcmToken = null;
      console.log('✅ FCM token deleted');
    } catch (error) {
      console.error('❌ Failed to delete token:', error);
    }
  }
}

// Create global instance
window.webPushManager = new WebPushManager();

// Auto-initialize when Firebase is ready
window.addEventListener('load', () => {
  // Wait for Firebase to be initialized by Flutter
  const checkFirebase = setInterval(() => {
    if (typeof firebase !== 'undefined' && firebase.apps.length > 0) {
      clearInterval(checkFirebase);
      console.log('🔥 Firebase ready, WebPushManager available');
      // Don't auto-request permission - let app decide when to ask
    }
  }, 100);
});

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = WebPushManager;
}
