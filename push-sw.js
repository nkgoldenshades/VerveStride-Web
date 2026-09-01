// ═══════════════════════════════════════════════════════════════════════════
// VERVESTRIDE WEB PUSH SERVICE WORKER
// Standalone service worker for web push notifications
// ═══════════════════════════════════════════════════════════════════════════

const CACHE_NAME = 'vervestride-push-v1';
const APP_NAME = 'VerveStride AI';

// Install event
self.addEventListener('install', (event) => {
    console.log('🔧 VerveStride Push SW: Installing...');
    self.skipWaiting();
});

// Activate event
self.addEventListener('activate', (event) => {
    console.log('✅ VerveStride Push SW: Activated');
    event.waitUntil(clients.claim());
});

// Push event - handle incoming push notifications
self.addEventListener('push', (event) => {
    console.log('🔔 Push received:', event);
    
    let data = {
        title: APP_NAME,
        body: 'You have a new notification',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: 'vervestride-notification',
        data: {}
    };

    // Parse push data if available
    if (event.data) {
        try {
            const pushData = event.data.json();
            data = { ...data, ...pushData };
        } catch (e) {
            console.warn('Failed to parse push data as JSON:', e);
            data.body = event.data.text();
        }
    }

    // Notification options
    const options = {
        body: data.body,
        icon: data.icon,
        badge: data.badge,
        image: data.image,
        data: data.data,
        tag: data.tag,
        requireInteraction: data.requireInteraction || false,
        silent: data.silent || false,
        timestamp: Date.now(),
        vibrate: data.vibrate || [200, 100, 200],
        actions: data.actions || [
            {
                action: 'open',
                title: 'Open App',
                icon: '/icons/Icon-192.png'
            },
            {
                action: 'dismiss',
                title: 'Dismiss',
                icon: '/icons/Icon-192.png'
            }
        ]
    };

    // Show the notification
    event.waitUntil(
        self.registration.showNotification(data.title, options)
    );
});

// Notification click event
self.addEventListener('notificationclick', (event) => {
    console.log('🖱️ Notification clicked:', event);
    
    const notification = event.notification;
    const action = event.action;
    const data = notification.data || {};

    notification.close();

    // Handle different actions
    if (action === 'dismiss') {
        console.log('Notification dismissed by user');
        return;
    }

    // Determine URL to open
    let urlToOpen = '/';
    
    if (action === 'open' || !action) {
        urlToOpen = data.url || '/';
    } else if (data.actions && data.actions[action]) {
        urlToOpen = data.actions[action].url || '/';
    }

    // Open the URL
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true })
            .then((clientList) => {
                // Check if app is already open
                for (const client of clientList) {
                    if (client.url.includes(urlToOpen) && 'focus' in client) {
                        return client.focus();
                    }
                }
                
                // Open new window if app not already open
                if (clients.openWindow) {
                    return clients.openWindow(urlToOpen);
                }
            })
            .catch((error) => {
                console.error('Failed to handle notification click:', error);
            })
    );
});

// Notification close event
self.addEventListener('notificationclose', (event) => {
    console.log('🔕 Notification closed:', event);
    
    // Optional: Track notification dismissal
    const data = event.notification.data || {};
    if (data.trackDismissal) {
        // You could send analytics data here
        console.log('Tracking notification dismissal for:', data);
    }
});

// Background sync for offline notifications (optional)
self.addEventListener('sync', (event) => {
    console.log('🔄 Background sync:', event);
    
    if (event.tag === 'vervestride-notification-sync') {
        event.waitUntil(
            // Handle any offline notification syncing
            handleNotificationSync()
        );
    }
});

async function handleNotificationSync() {
    try {
        // Check for any pending notifications to send
        // This is where you'd implement offline notification queuing
        console.log('Handling notification sync...');
    } catch (error) {
        console.error('Background sync failed:', error);
    }
}

// Message event - communication with main app
self.addEventListener('message', (event) => {
    console.log('📨 SW received message:', event.data);
    
    const { type, payload } = event.data;
    
    switch (type) {
        case 'SHOW_NOTIFICATION':
            showNotification(payload);
            break;
        case 'GET_SUBSCRIPTION':
            getSubscriptionInfo(event);
            break;
        case 'CLEAR_NOTIFICATIONS':
            clearAllNotifications(payload.tag);
            break;
        default:
            console.warn('Unknown message type:', type);
    }
});

async function showNotification(payload) {
    const options = {
        body: payload.body || 'New notification',
        icon: payload.icon || '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: payload.tag || 'vervestride-notification',
        data: payload.data || {},
        actions: payload.actions || []
    };
    
    await self.registration.showNotification(
        payload.title || APP_NAME,
        options
    );
}

async function getSubscriptionInfo(event) {
    try {
        const subscription = await self.registration.pushManager.getSubscription();
        event.ports[0].postMessage({
            type: 'SUBSCRIPTION_INFO',
            subscription: subscription ? {
                endpoint: subscription.endpoint,
                keys: {
                    p256dh: arrayBufferToBase64(subscription.getKey('p256dh')),
                    auth: arrayBufferToBase64(subscription.getKey('auth'))
                }
            } : null
        });
    } catch (error) {
        event.ports[0].postMessage({
            type: 'ERROR',
            error: error.message
        });
    }
}

async function clearAllNotifications(tag) {
    const notifications = await self.registration.getNotifications({ tag });
    notifications.forEach(notification => notification.close());
    console.log(`Cleared ${notifications.length} notifications`);
}

// Utility function
function arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
}