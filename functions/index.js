


/**
 * 
 * Cloud Functions for KoFund - v2 API
 * UPDATED FOR COMMUNITY-BASED NOTIFICATION SYSTEM
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const functions = require("firebase-functions");
// Initialize Firebase Admin SDK
admin.initializeApp();

// Set global options
setGlobalOptions({
  region: "us-central1",
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: "256MiB",
});

console.log("✅ Firebase Cloud Functions v2 ready");

// Firestore and Messaging instances
const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Helper to ensure all values in a Map are strings (required for FCM data)
 */
function ensureStringData(data) {
  const sanitized = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) {
      sanitized[key] = "";
    } else if (typeof value === "object") {
      sanitized[key] = JSON.stringify(value);
    } else {
      sanitized[key] = String(value);
    }
  }
  return sanitized;
}

// ==================== TOKEN MANAGEMENT FUNCTIONS ====================

/**
 * Register FCM token with user and community context
 * ⭐ UPDATED: Uses new token storage structure
 */
exports.registerFCMToken = onCall(
  {
    region: "us-central1",
    cors: true,
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      const { data, auth } = request;
      
      if (!auth) {
        throw new Error("Authentication required");
      }
      
      const { token, communityIds = [], deviceId } = data || {};
      
      if (!token) {
        throw new Error("FCM token is required");
      }
      
      const userId = auth.uid;
      const currentUserDoc = await db.collection('users').doc(userId).get();
      const currentUserData = currentUserDoc.data() || {};
      if (!currentUserDoc.exists || currentUserData.isVirtualUser === true) {
        throw new HttpsError("failed-precondition", "Only real users can register notification tokens");
      }
      console.log(`📱 Registering token for user: ${userId}`);
      console.log(`   Token: ${token.substring(0, 20)}...`);
      console.log(`   Communities: ${JSON.stringify(communityIds)}`);
      
      // ⭐ NEW: Check if token already exists for a DIFFERENT user
      const existingTokenDoc = await db
        .collection('user_notification_tokens')
        .doc(token)
        .get();
      
      if (existingTokenDoc.exists) {
        const existingData = existingTokenDoc.data();
        
        // If token belongs to a different user, mark it as inactive
        if (existingData.userId !== userId) {
          console.log(`⚠️ Token reassigned from user ${existingData.userId} to ${userId}`);
          
          await existingTokenDoc.ref.update({
            isActive: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            deactivatedReason: 'token_reassigned',
            reassignedTo: userId,
          });
          
          // Remove from old user's document
          await db
            .collection('users')
            .doc(existingData.userId)
            .update({
              fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
            });
        }
      }
      
      // ⭐ NEW: Store token in dedicated collection with community context
      await db
        .collection('user_notification_tokens')
        .doc(token)
        .set({
          token: token,
          userId: userId,
          communityIds: Array.isArray(communityIds) ? communityIds : [],
          deviceId: deviceId || 'unknown',
          isActive: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      
      // Also store in user document for backward compatibility
      await db
        .collection('users')
        .doc(userId)
        .update({
          fcmTokens: admin.firestore.FieldValue.arrayUnion(token),
          notificationCommunities: Array.isArray(communityIds) ? communityIds : [],
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      console.log(`✅ Token registered successfully for user ${userId}`);
      
      return {
        success: true,
        message: "FCM token registered successfully",
        token: token.substring(0, 20) + "...",
        communityIds: Array.isArray(communityIds) ? communityIds : [],
        userId,
        timestamp: new Date().toISOString(),
      };
      
    } catch (error) {
      console.error("❌ Error in registerFCMToken:", error);
      throw new Error(`Failed to register FCM token: ${error.message}`);
    }
  }
);




// Make sure your functions/index.js has the handleJoinWeb function
// Add this if you haven't:


// In functions/index.js
// ✅ MUST EXIST: This function handles /join/** routes
exports.handleJoinWeb = functions.https.onRequest((req, res) => {
  // Extract invite code from URL: /join/CUOVUA3H
  const path = req.path;
  const segments = path.split('/').filter(s => s);
  
  let inviteCode = '';
  
  if (segments.length >= 2 && segments[0] === 'join') {
    inviteCode = segments[1]; // Get the code
  } else if (req.query.code) {
    inviteCode = req.query.code; // Fallback to query param
  }
  
  // Clean the code
  inviteCode = inviteCode.toUpperCase().replace(/[^A-Z0-9]/g, '');
  
  if (!inviteCode) {
    // No code, redirect to home
    res.redirect('https://kofund-153ba.web.app');
    return;
  }
  
  // Create HTML that redirects to app
  const html = `
  <!DOCTYPE html>
  <html>
  <head>
    <title>Join KoFund Community</title>
    <meta http-equiv="refresh" content="0; url=kofund:///join-community?code=${inviteCode}">
    <script>
      // Try to open app immediately
      window.location.href = "kofund:///join-community?code=${inviteCode}";
      
      // Fallback after 2 seconds
      setTimeout(() => {
        document.getElementById('fallback').style.display = 'block';
      }, 2000);
    </script>
    <style>
      body { 
        font-family: Arial, sans-serif; 
        text-align: center; 
        padding: 50px; 
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
      }
      .container {
        max-width: 600px;
        padding: 40px;
        background: rgba(255, 255, 255, 0.1);
        backdrop-filter: blur(10px);
        border-radius: 20px;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
      }
      h1 {
        font-size: 2.5rem;
        margin-bottom: 20px;
      }
      .code-display {
        background: white;
        color: #333;
        padding: 20px;
        border-radius: 10px;
        font-size: 24px;
        font-weight: bold;
        margin: 20px 0;
        letter-spacing: 2px;
      }
      .button {
        display: inline-block;
        margin: 20px;
        padding: 15px 30px;
        background: white;
        color: #667eea;
        text-decoration: none;
        border-radius: 50px;
        font-weight: bold;
        transition: transform 0.3s;
      }
      .button:hover {
        transform: translateY(-5px);
      }
    </style>
  </head>
  <body>
    <div class="container">
      <div id="redirecting">
        <h1>🎯 KoFund</h1>
        <p>Opening KoFund app...</p>
        <p>Invite Code: <strong>${inviteCode}</strong></p>
      </div>
      <div id="fallback" style="display: none;">
        <h1>Join KoFund Community</h1>
        <p>Copy this invite code:</p>
        <div class="code-display">${inviteCode}</div>
        <p>Open the KoFund app and enter this code</p>
        
        <div style="margin: 30px 0;">
          <button onclick="copyCode('${inviteCode}')" class="button">📋 Copy Code</button>
          <a href="kofund:///join-community?code=${inviteCode}" class="button">📱 Open App</a>
          <a href="https://kofund-153ba.web.app" class="button" style="background: transparent; color: white; border: 2px solid white;">🌐 Visit Website</a>
        </div>
        
        <p style="font-size: 0.9rem; opacity: 0.8;">
          Having trouble? Contact support@kofund.app
        </p>
      </div>
    </div>
    
    <script>
      function copyCode(code) {
        navigator.clipboard.writeText(code);
        alert('Code copied: ' + code);
      }
      
      // Show fallback after 3 seconds
      setTimeout(() => {
        document.getElementById('redirecting').style.display = 'none';
        document.getElementById('fallback').style.display = 'block';
      }, 3000);
    </script>
  </body>
  </html>
  `;
  
  res.status(200).send(html);
});

// Unused 'api' function removed.

// Unused 'join' function removed.
/**
 * Unregister FCM token when user logs out
 */
exports.unregisterFCMToken = onCall(
  {
    region: "us-central1",
    cors: true,
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      const { data, auth } = request;
      
      if (!auth) {
        throw new Error("Authentication required");
      }
      
      const { token } = data || {};
      const userId = auth.uid;
      
      if (!token) {
        throw new Error("FCM token is required");
      }
      
      console.log(`📱 Unregistering token for user: ${userId}`);
      console.log(`   Token: ${token.substring(0, 20)}...`);
      
      // Mark token as inactive in dedicated collection
      await db
        .collection('user_notification_tokens')
        .doc(token)
        .update({
          isActive: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          deactivatedReason: 'user_logout',
          logoutAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      // Remove from user's document
      await db
        .collection('users')
        .doc(userId)
        .update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
        });
      
      console.log(`✅ Token unregistered for user ${userId}`);
      
      return {
        success: true,
        message: "FCM token unregistered successfully",
        userId,
        timestamp: new Date().toISOString(),
      };
      
    } catch (error) {
      console.error("❌ Error in unregisterFCMToken:", error);
      throw new Error(`Failed to unregister FCM token: ${error.message}`);
    }
  }
);

// ==================== MAIN COMMUNITY NOTIFICATION FUNCTION ====================

/**
 * Send notification to all users in a specific community
 * ⭐ UPDATED: Uses new token structure and excludes sender
 */
exports.sendCommunityNotification = onCall(
  {
    region: "us-central1",
    cors: true,
    timeoutSeconds: 30,
    enforceAppCheck: false, 
  },
  async (request) => {
    try {
      const { data, auth } = request;
      
      if (!auth) {
        throw new Error("Authentication required");
      }
      
      const { 
        communityId,
        title, 
        body, 
        type = "announcement",
        eventId = null,
        senderName = "KoFund",
        skipPush = false, // 🆕 NEW: Option to skip push notification delivery
        targetRole = null, // 🆕 NEW: Filter by role (e.g., 'admin')
        data: notificationData = {}
      } = data || {};
      
      console.log("📢 sendCommunityNotification called");
      console.log("Community:", communityId);
      console.log("Title:", title);
      console.log("Sender:", auth.uid);
      console.log("Type:", type);
      console.log("Skip Push:", skipPush);
      
      if (!communityId || !title || !body) {
        throw new HttpsError("invalid-argument", "Missing required fields: communityId, title, body");
      }
      
      const now = new Date();
      
      // ⭐ NEW: Get base notificationId from data or generate
      const baseNotificationId = notificationData.notificationId || 
                                `${now.getTime()}`;
      
      console.log("📝 Base notificationId:", baseNotificationId);
      
      // 1. Verify sender belongs to the community
      const senderDoc = await db.collection('users').doc(auth.uid).get();
      if (!senderDoc.exists) {
        throw new Error("Sender user not found");
      }
      
      const senderData = senderDoc.data();
      const senderCommunities = senderData.notificationCommunities || [];
      const senderPrimaryCommunity = senderData.communityId;
      
      const isAuthorized = type === 'pendingUser' ||
                          senderPrimaryCommunity === communityId || 
                          senderCommunities.includes(communityId);
      
      if (!isAuthorized) {
        console.error(`❌ Sender ${auth.uid} not authorized for community ${communityId}`);
        throw new HttpsError("permission-denied", "Sender is not a member of this community");
      }

      // 🛡️ SECURITY: Only admins or developers can send community-wide notifications (except join requests)
      const isDeveloper = (auth.token && auth.token.email && auth.token.email.endsWith('@kofund.in')) || senderData.isDeveloper === true;
      if (type !== 'pendingUser' && senderData.role !== 'admin' && !isDeveloper) {
        console.error(`❌ Non-admin/non-developer sender ${auth.uid} tried to send community notification`);
        throw new HttpsError("permission-denied", "Only administrators or developers can send community notifications");
      }
      
      // 2. Get community info
      const communityDoc = await db.collection('communities').doc(communityId).get();
      
      if (!communityDoc.exists) {
        throw new Error("Community not found");
      }
      
      const communityData = communityDoc.data();
      const communityName = communityData.name || 'Community';
      
      // 3. ✅ ROBUST: Get tokens from BOTH collection and user doc for maximum reliability
      const tokensCollectionSnapshot = await db
        .collection('user_notification_tokens')
        .where('isActive', '==', true)
        .where('communityIds', 'array-contains', communityId)
        .get();

      console.log(`📱 Found ${tokensCollectionSnapshot.size} valid tokens in dedicated collection`);

      const communityMembersSnapshot = await db
        .collection('users')
        .where('communityId', '==', communityId)
        .where('isApproved', '==', true)
        .get();

      // Create a map of member IDs to their data for quick role lookups
      const memberDataMap = new Map();
      for (const doc of communityMembersSnapshot.docs) {
        const memberData = doc.data();
        if (memberData.isVirtualUser === true) continue;
        memberDataMap.set(doc.id, memberData);
      }

      console.log(`👥 Found ${communityMembersSnapshot.size} approved members in users collection`);
      if (targetRole) console.log(`🎯 Filtering by targetRole: ${targetRole}`);

      // Collect tokens and user info
      const allTokens = [];
      const tokenToUserMap = new Map();
      const usersToNotify = new Set(); // Track unique users

      // First, add tokens from dedicated collection
      for (const tokenDoc of tokensCollectionSnapshot.docs) {
        const tData = tokenDoc.data();
        const token = tData.token;
        const userId = tData.userId;
        
        if (userId === auth.uid) continue; // Skip sender

        const mData = memberDataMap.get(userId);
        if (!mData) continue;
        
        // Filter by role if specified
        if (targetRole) {
          if (mData.role !== targetRole) continue;
        }
        
        if (typeof token === 'string' && token.length >= 50) {
          allTokens.push(token);
          tokenToUserMap.set(token, userId);
          usersToNotify.add(userId);
        }
      }

      // Second, add tokens from user docs (fallback/sync)
      for (const userDoc of communityMembersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();

        // Skip handled or invalid cases
        if (userId === auth.uid || userData.isVirtualUser === true) continue;
        
        // Filter by role if specified
        if (targetRole && userData.role !== targetRole) continue;

        // Collect all FCM tokens for this user
        const fcmTokens = userData.fcmTokens || [];
        for (const token of fcmTokens) {
          if (typeof token === 'string' && token.length >= 50 && !tokenToUserMap.has(token)) {
            allTokens.push(token);
            tokenToUserMap.set(token, userId);
            usersToNotify.add(userId);
          }
        }
        
        // Ensure user is in notify list for in-app DB entry even if no tokens
        usersToNotify.add(userId);
      }

      // Unique tokens list
      const uniqueTokens = [...new Set(allTokens)];
      console.log(`📱 Unique tokens to notify: ${uniqueTokens.length}`);
      console.log(`👥 Total users for in-app notifications: ${usersToNotify.size}`);
      
      // 5. Create notification documents for each user
      const notificationsBatch = db.batch();
      let notificationsCreated = 0;
      
      for (const userId of usersToNotify) {
        const notificationId = `${baseNotificationId}_${userId}`;
        const notificationRef = db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId);
        
        // Removed redundant existence check to reduce reads. 'set' is idempotent here.

        
        const notification = {
          id: notificationId,
          title: title,
          body: body,
          type: type,
          priority: type === 'event' || type === 'reminder' ? 'high' : 'normal',
          data: {
            ...notificationData,
            communityId,
            type,
            eventId: eventId || '',
            senderId: auth.uid,
            senderName: senderName || senderData.displayName || 'KoFund Member',
            sentFromApp: true,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            notificationId: baseNotificationId,
            timestamp: now.toISOString(),
          },
          userId: userId,
          communityId: communityId,
          eventId: eventId || null,
          isRead: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          deepLink: notificationData.deepLink || null,
          senderName: senderName || senderData.displayName || 'KoFund Member',
          senderId: auth.uid,
        };
        
        notificationsBatch.set(notificationRef, notification);
        notificationsCreated++;
      }
      
      // Commit notifications batch
      if (notificationsCreated > 0) {
        await notificationsBatch.commit();
        console.log(`✅ Created ${notificationsCreated} notification documents`);
      }
      
      // 6. Send push notifications
      let pushNotificationsSent = 0;
      const failedTokens = [];
      
      if (!skipPush && uniqueTokens.length > 0) {
        // Split into chunks of 500 (FCM limit)
        const chunkSize = 500;
        
        for (let i = 0; i < uniqueTokens.length; i += chunkSize) {
          const tokenChunk = uniqueTokens.slice(i, i + chunkSize);
          
          // ⭐ CRITICAL: Ensure ALL data values are strings for FCM
          const sanitizedData = ensureStringData({
            ...notificationData,
            communityId,
            type,
            eventId: eventId || '',
            senderId: auth.uid,
            senderName: senderName || senderData.displayName || 'KoFund Member',
            sentFromApp: 'true',
            notificationId: baseNotificationId,
            timestamp: now.toISOString(),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            title: title,
            body: body,
          });

          const message = {
            notification: {
              title: title,
              body: body,
            },
            data: sanitizedData,
            tokens: tokenChunk,
            android: {
              priority: 'high',
              notification: {
                icon: 'ic_notification',
                color: '#764ba2',
                tag: baseNotificationId,
              },
            },
            apns: {
              payload: {
                aps: {
                  alert: {
                    title: title,
                    body: body,
                  },
                  contentAvailable: true,
                  badge: 1,
                  sound: 'default',
                  category: 'event_announcement',
                },
              },
            },
          };
          
          try {
            console.log(`📤 Sending chunk ${Math.floor(i/chunkSize) + 1} with ${tokenChunk.length} tokens...`);
            
            const response = await messaging.sendEachForMulticast(message);
            
            pushNotificationsSent += response.successCount;
            console.log(`✅ Chunk ${Math.floor(i/chunkSize) + 1}: ${response.successCount}/${tokenChunk.length} successful`);
            
            // Handle failed tokens
            if (response.failureCount > 0) {
              response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                  const failedToken = tokenChunk[idx];
                  failedTokens.push({
                    token: failedToken.substring(0, 20) + '...',
                    error: resp.error?.message || 'Unknown error',
                  });
                  
                  // Remove invalid tokens (registration-token-not-registered)
                  if (resp.error?.code === 'messaging/registration-token-not-registered') {
                    console.log(`🧹 Removing invalid token: ${failedToken.substring(0, 20)}...`);
                    
                    // Remove from token collection
                    db.collection('user_notification_tokens')
                      .doc(failedToken)
                      .update({
                        isActive: false,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        deactivatedReason: 'invalid_token',
                      })
                      .catch(err => console.log(`⚠️ Error removing token: ${err.message}`));
                    
                    // Remove from user's document
                    const userId = tokenToUserMap.get(failedToken);
                    if (userId) {
                      db.collection('users')
                        .doc(userId)
                        .update({
                          fcmTokens: admin.firestore.FieldValue.arrayRemove(failedToken),
                        })
                        .catch(err => console.log(`⚠️ Error removing token from user: ${err.message}`));
                    }
                  }
                }
              });
            }
            
          } catch (error) {
            console.error(`❌ Error sending chunk:`, error.message);
          }
        }
      }
      
      // 7. Return results
      const result = {
        success: true,
        message: `Notification sent to community ${communityName}`,
        title,
        body,
        type,
        communityId,
        communityName,
        senderId: auth.uid,
        senderName: senderName || senderData.displayName || 'KoFund Member',
        senderExcluded: true,
        usersNotified: usersToNotify.size,
        notificationsCreated: notificationsCreated,
        pushNotificationsSent: pushNotificationsSent,
        uniqueTokensUsed: uniqueTokens.length,
        failedTokens: failedTokens.length,
        baseNotificationId,
        timestamp: now.toISOString(),
      };
      
      console.log("✅ sendCommunityNotification completed successfully");
      console.log("📊 Results:", JSON.stringify(result, null, 2));
      
      return result;
      
    } catch (error) {
      console.error("❌ Error in sendCommunityNotification:", error);
      console.error("📌 Stack trace:", error.stack);
      
      throw new Error(`Failed to send community notification: ${error.message}`);
    }
  }
);

// ==================== SINGLE USER NOTIFICATION FUNCTION ====================

/**
 * Send notification to a specific user
 * ⭐ UPDATED: With community validation
 */
exports.sendUserNotification = onCall(
  {
    region: "us-central1",
    cors: true,
    timeoutSeconds: 30,
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      const { data, auth } = request;
      
      if (!auth) {
        throw new Error("Authentication required");
      }
      
      const { 
        userId,
        title, 
        body, 
        type = "announcement",
        data: notificationData = {},
        eventId = null,
        communityId = null,
        senderName = "KoFund",
      } = data || {};
      
      console.log("📨 sendUserNotification called");
      console.log("Target user:", userId);
      console.log("Sender:", auth.uid);
      
      if (!userId || !title || !body) {
        throw new Error("Missing required fields: userId, title, body");
      }
      
      // ✅ FIXED: Validate sender permissions (check BOTH primary communityId AND list)
      if (auth.uid !== userId) {
        // Check if sender is admin or in same community
        const senderDoc = await db.collection('users').doc(auth.uid).get();
        if (!senderDoc.exists) {
          throw new Error("Sender not found");
        }
        
        const senderData = senderDoc.data();
        const isAdmin = senderData.role === 'admin';
        
        // If community is specified, check if sender is in same community
        if (communityId && !isAdmin) {
          const senderPrimaryCommunity = senderData.communityId || null;
          const senderCommunities = senderData.notificationCommunities || [];
          
          // ✅ Check BOTH the primary communityId AND the notificationCommunities array
          const isAuthorized = senderPrimaryCommunity === communityId ||
                               senderCommunities.includes(communityId);
          
          if (!isAuthorized) {
            console.error(`❌ Sender ${auth.uid} not authorized for community ${communityId}`);
            console.error(`   Primary: ${senderPrimaryCommunity}, List: ${senderCommunities.join(', ')}`);
            throw new Error("Sender is not a member of the specified community");
          }
        }
      }
      
      const now = new Date();
      
      // Use notificationId from data or generate
      const notificationId = notificationData.notificationId || 
                            `${now.getTime()}_${userId}`;
      
      // 1. Get target user info
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw new Error("Target user not found");
      }
      
      const userData = userDoc.data();
      
      // Check if user is eligible for notifications
      const isEligible = 
        userData.isApproved === true &&
        userData.isVirtualUser !== true;
      
      if (!isEligible) {
        throw new Error("Target user is not eligible for notifications");
      }
      
      // Removed redundant existence check/read to reduce costs.
      if (true) {
        // Create notification document
        const notificationRef = db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId);
        
        const notification = {
          id: notificationId,
          title: title,
          body: body,
          type: type,
          priority: type === 'event' || type === 'reminder' ? 'high' : 'normal',
          data: {
            ...notificationData,
            userId: userId,
            communityId: communityId || userData.communityId || null,
            type: type,
            eventId: eventId || null,
            senderId: auth.uid,
            senderName: senderName || userData.displayName || 'KoFund',
            sentFromApp: true,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            notificationId: notificationId,
            timestamp: now.toISOString(),
          },
          userId: userId,
          communityId: communityId || userData.communityId || null,
          eventId: eventId || null,
          isRead: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          deepLink: notificationData.deepLink || null,
          senderName: senderName || 'KoFund',
          senderId: auth.uid,
        };
        
        await notificationRef.set(notification);
        console.log(`✅ Created notification document: ${notificationId}`);
      }

      
      // 3. Get user's active tokens
      const tokensSnapshot = await db
        .collection('user_notification_tokens')
        .where('userId', '==', userId)
        .where('isActive', '==', true)
        .get();
      
      const tokens = tokensSnapshot.docs
        .map(doc => doc.data().token)
        .filter(token => typeof token === 'string' && token.length > 50);
      
      const uniqueTokens = [...new Set(tokens)];
      console.log(`📱 Found ${uniqueTokens.length} active tokens for user ${userId}`);
      
      // 4. Send push notification
      let pushSent = false;
      let pushMessageId = null;
      
      if (uniqueTokens.length > 0) {
        // ⭐ CRITICAL: Ensure ALL data values are strings for FCM
        const sanitizedData = ensureStringData({
          ...notificationData,
          userId: userId,
          communityId: communityId || userData.communityId || '',
          type: type,
          eventId: eventId || '',
          senderId: auth.uid,
          senderName: senderName || 'KoFund',
          sentFromApp: 'true',
          notificationId: notificationId,
          timestamp: now.toISOString(),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          title: title,
          body: body,
        });

        const message = {
          notification: {
            title: title,
            body: body,
          },
          data: sanitizedData,
          tokens: uniqueTokens,
          android: {
            priority: 'high',
            notification: {
              icon: 'ic_notification',
              color: '#764ba2',
            },
          },
          apns: {
            payload: {
              aps: {
                contentAvailable: true,
                badge: 1,
                sound: 'default',
              },
            },
          },
        };
        
        try {
          const response = await messaging.sendEachForMulticast(message);
          pushSent = response.successCount > 0;
          
          if (response.successCount > 0) {
            pushMessageId = response.responses[0].messageId;
            console.log(`✅ Push notification sent successfully`);
          }
          
          // Clean invalid tokens
          if (response.failureCount > 0) {
            response.responses.forEach((resp, idx) => {
              if (!resp.success && resp.error?.code === 'messaging/registration-token-not-registered') {
                const failedToken = uniqueTokens[idx];
                console.log(`🧹 Removing invalid token: ${failedToken.substring(0, 20)}...`);
                
                // Remove from token collection
                db.collection('user_notification_tokens')
                  .doc(failedToken)
                  .update({
                    isActive: false,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    deactivatedReason: 'invalid_token',
                  })
                  .catch(err => console.log(`⚠️ Error removing token: ${err.message}`));
                
                // Remove from user's document
                db.collection('users')
                  .doc(userId)
                  .update({
                    fcmTokens: admin.firestore.FieldValue.arrayRemove(failedToken),
                  })
                  .catch(err => console.log(`⚠️ Error removing token from user: ${err.message}`));
              }
            });
          }
          
        } catch (pushError) {
          console.error("❌ Push notification error:", pushError.message);
        }
      }
      
      // 5. Return results
      return {
        success: true,
        message: "User notification sent successfully",
        notification: {
          id: notificationId,
          title: title,
          userId: userId,
          pushSent: pushSent,
          pushMessageId: pushMessageId,
          tokensUsed: uniqueTokens.length,
        },
        timestamp: now.toISOString(),
      };
      
    } catch (error) {
      console.error("❌ Error in sendUserNotification:", error);
      throw new Error(`Failed to send user notification: ${error.message}`);
    }
  }
);

// ==================== TOKEN CLEANUP FUNCTION ====================

/**
 * Clean up inactive or invalid tokens
 * Run this function periodically (e.g., once a day)
 */
exports.cleanupNotificationTokens = onCall(
  {
    region: "us-central1",
    cors: true,
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      const { auth } = request;
      
      // Optional: Add admin check if you want to secure this function
      // if (!auth || auth.uid !== 'admin-user-id') {
      //   throw new Error("Admin access required");
      // }
      
      console.log("🧹 Starting token cleanup...");
      
      const now = new Date();
      const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
      
      // 1. Find tokens not updated in last 30 days
      const oldTokensSnapshot = await db
        .collection('user_notification_tokens')
        .where('isActive', '==', true)
        .where('updatedAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .limit(100) // Process in batches
        .get();
      
      console.log(`Found ${oldTokensSnapshot.size} old tokens to cleanup`);
      
      let deactivatedCount = 0;
      
      // 2. Deactivate old tokens
      for (const tokenDoc of oldTokensSnapshot.docs) {
        const tokenData = tokenDoc.data();
        
        await tokenDoc.ref.update({
          isActive: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          deactivatedReason: 'inactive_too_long',
          deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Remove from user's fcmTokens array
        if (tokenData.userId) {
          try {
            await db
              .collection('users')
              .doc(tokenData.userId)
              .update({
                fcmTokens: admin.firestore.FieldValue.arrayRemove(tokenData.token),
              });
          } catch (error) {
            console.log(`⚠️ Error removing token from user ${tokenData.userId}: ${error.message}`);
          }
        }
        
        deactivatedCount++;
      }
      
      // 3. Find invalid tokens (already marked as inactive)
      const invalidTokensSnapshot = await db
        .collection('user_notification_tokens')
        .where('isActive', '==', false)
        .where('updatedAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .limit(100)
        .get();
      
      let deletedCount = 0;
      
      // 4. Delete very old inactive tokens
      for (const tokenDoc of invalidTokensSnapshot.docs) {
        await tokenDoc.ref.delete();
        deletedCount++;
      }
      
      console.log("✅ Token cleanup completed");
      
      return {
        success: true,
        message: "Token cleanup completed",
        stats: {
          oldTokensFound: oldTokensSnapshot.size,
          tokensDeactivated: deactivatedCount,
          tokensDeleted: deletedCount,
        },
        timestamp: now.toISOString(),
      };
      
    } catch (error) {
      console.error("❌ Error in cleanupNotificationTokens:", error);
      throw new Error(`Failed to cleanup tokens: ${error.message}`);
    }
  }
);

// ==================== CONTRIBUTION REMINDER FUNCTION ====================

/**
 * Send contribution reminders to users in a community/event
 * ⭐ UPDATED: Uses new token structure
 */
exports.sendeventContributionReminders = onCall(
  {
    region: "us-central1",
    cors: true,
    timeoutSeconds: 60,
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      const { data, auth } = request;
      
      if (!auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }
      
      const { 
        communityId,
        eventId = null,
        sendTest = false,
        testUserId = null,
      } = data || {};
      
      console.log("⏰ sendeventContributionReminders called");
      console.log("Community:", communityId);
      console.log("event:", eventId || "All events");
      
      if (!communityId) {
        throw new HttpsError("invalid-argument", "Missing required field: communityId");
      }

      // 🛡️ SECURITY: Verify sender is an admin of the community
      const senderDoc = await db.collection('users').doc(auth.uid).get();
      if (!senderDoc.exists) {
        throw new HttpsError("not-found", "Sender user not found");
      }
      const senderData = senderDoc.data();
      const isAdminUser = senderData.role === 'admin' || senderData.isAdmin === true;
      if (!isAdminUser) {
        throw new HttpsError("permission-denied", "Only admins can send reminders");
      }
      
      const now = new Date();
      const baseNotificationId = `${now.getTime()}`;
      
      // 1. Get community info
      const communityDoc = await db.collection('communities').doc(communityId).get();
      
      if (!communityDoc.exists) {
        throw new Error("Community not found");
      }
      
      const communityData = communityDoc.data();
      const communityName = communityData.name || 'Community';
      
      // 2. Get target events - FIXED: events in root 'events' collection
      let eventsSnapshot = [];
      
      if (eventId) {
        // FIXED: Query root 'events' collection
        const eventDoc = await db.collection('events').doc(eventId).get();
        
        if (eventDoc.exists) {
          const eventData = eventDoc.data();
          // Check if event belongs to this community
          if (eventData.communityId === communityId && eventData.status === 'active') {
            eventsSnapshot = [eventDoc];
          } else {
            return {
              success: true,
              message: "event not found or not active in this community",
              remindersSent: 0,
              communityId,
              communityName,
              timestamp: now.toISOString(),
            };
          }
        } else {
          return {
            success: true,
            message: "event not found",
            remindersSent: 0,
            communityId,
            communityName,
            timestamp: now.toISOString(),
          };
        }
      } else {
        // FIXED: Query root 'events' collection
        const eventsQuery = db
          .collection('events')
          .where('communityId', '==', communityId)
          .where('status', '==', 'active');
        
        const querySnapshot = await eventsQuery.get();
        eventsSnapshot = querySnapshot.docs;
      }
      
      console.log(`📋 Found ${eventsSnapshot.length} event(s) to process`);
      
      if (eventsSnapshot.length === 0) {
        return {
          success: true,
          message: "No active events found",
          remindersSent: 0,
          communityId,
          communityName,
          timestamp: now.toISOString(),
        };
      }
      
      const results = [];
      let totalRemindersSent = 0;
      let totalNotificationsCreated = 0;
      
      // 3. ✅ OPTIMIZED: Fetch all community users once to avoid N reads
      const communityUsersSnapshot = await db
        .collection('users')
        .where('communityId', '==', communityId)
        .where('isApproved', '==', true)
        .get();
      
      const userMap = new Map();
      communityUsersSnapshot.forEach(doc => userMap.set(doc.id, doc.data()));
      console.log(`👥 Loaded ${userMap.size} community users into memory`);

      // 3.5 ✅ NEW: Fetch all active tokens for this community from dedicated collection
      const communityTokensSnapshot = await db
        .collection('user_notification_tokens')
        .where('isActive', '==', true)
        .where('communityIds', 'array-contains', communityId)
        .get();
      
      const userTokensMap = new Map(); // userId -> Set of tokens
      communityTokensSnapshot.forEach(doc => {
        const tData = doc.data();
        if (tData.userId && tData.token) {
          if (!userTokensMap.has(tData.userId)) {
            userTokensMap.set(tData.userId, new Set());
          }
          userTokensMap.get(tData.userId).add(tData.token);
        }
      });
      console.log(`📱 Loaded ${communityTokensSnapshot.size} tokens for ${userTokensMap.size} users into memory`);

      // 4. Process each event
      for (const eventDoc of eventsSnapshot) {
        const event = {
          id: eventDoc.id,
          ...eventDoc.data()
        };
        
        console.log(`\n🎯 Processing event: ${event.title || event.id}`);
        
        // Check if event has reminder settings enabled
        if (!event.enableAutoReminders) {
          console.log(`⏭️ Skipping - auto reminders disabled`);
          continue;
        }
        
        const suggestedContribution = parseFloat(event.suggestedContribution) || 0;
        
        if (suggestedContribution <= 0) {
          console.log(`⏭️ Skipping - no suggested contribution amount`);
          continue;
        }
        
        // 5. ✅ OPTIMIZED: Fetch all contributions for this event once
        const allContributionsSnapshot = await db
          .collection('contributions')
          .where('eventId', '==', event.id)
          .where('status', '==', 'completed')
          .get();
        
        const userContributionsMap = new Map();
        allContributionsSnapshot.forEach(doc => {
          const c = doc.data();
          const amount = parseFloat(c.amount) || 0;
          userContributionsMap.set(c.userId, (userContributionsMap.get(c.userId) || 0) + amount);
        });
        
        // 6. Get participants
        const participantsSnapshot = await db
          .collection('participants')
          .where('eventId', '==', event.id)
          .where('status', '==', 'joined')
          .get();
        
        const participantsToRemind = [];
        const processedUserIds = new Set();
        
        for (const participantDoc of participantsSnapshot.docs) {
          const participant = participantDoc.data();
          const userId = participant.userId;
          
          if (processedUserIds.has(userId)) continue;
          processedUserIds.add(userId);
          
          if (sendTest && testUserId && userId !== testUserId) continue;
          
          // Use pre-fetched user data
          const userData = userMap.get(userId);
          if (!userData || userData.isVirtualUser === true) continue;
          
          const totalPaid = userContributionsMap.get(userId) || 0;
          const amountRemaining = Math.max(0, suggestedContribution - totalPaid);
          
          if (amountRemaining > 0) {
            participantsToRemind.push({
              userId,
              userData, // Carry user data for tokens
              userName: userData.displayName || participant.userName || 'User',
              amountRemaining,
              personalizedBody: `Hi ${userData.displayName || participant.userName || 'User'}, you have $${amountRemaining.toFixed(2)} remaining of your $${suggestedContribution.toFixed(2)} contribution for ${event.title}.`,
            });
          }
        }
        
        if (participantsToRemind.length === 0) continue;
        
        // 7. Batch Create Notifications
        const reminderTitle = `⏰ Contribution Reminder: ${event.title}`;
        const batch = db.batch();
        let eventNotificationsCreated = 0;
        
        for (const p of participantsToRemind) {
          const notificationId = `${baseNotificationId}_rem_${event.id}_${p.userId}`;
          const notificationRef = db.collection('users').doc(p.userId).collection('notifications').doc(notificationId);
          
          batch.set(notificationRef, {
            id: notificationId,
            title: reminderTitle,
            body: p.personalizedBody,
            type: 'reminder',
            subtype: 'contribution',
            priority: 'high',
            data: {
              communityId,
              eventId: event.id,
              eventName: event.title,
              amountRemaining: p.amountRemaining,
              suggestedContribution,
              senderId: auth.uid,
              sentFromApp: true,
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              notificationId: baseNotificationId,
            },
            userId: p.userId,
            communityId,
            eventId: event.id,
            senderName: 'KoFund Reminder',
            senderId: auth.uid,
            isRead: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            deepLink: `/events/${event.id}/contribute`,
          });
          eventNotificationsCreated++;
        }

        
        // Commit notifications batch
        if (!sendTest && eventNotificationsCreated > 0) {
          await batch.commit();
          totalNotificationsCreated += eventNotificationsCreated;
          console.log(`✅ Created ${eventNotificationsCreated} notifications in Firestore`);
        }
        
        // 8. Send push notifications
        let pushNotificationsSent = 0;
        const pushPromises = [];
        
        for (const p of participantsToRemind) {
          // Merge tokens from user document and dedicated collection
          const tokensFromDoc = p.userData.fcmTokens || [];
          const tokensFromCollection = userTokensMap.get(p.userId) || new Set();
          
          const combinedTokens = [...new Set([
            ...tokensFromDoc, 
            ...Array.from(tokensFromCollection)
          ])].filter(t => typeof t === 'string' && t.length >= 50);

          if (combinedTokens.length === 0) continue;
          
          // ⭐ CRITICAL: Ensure ALL data values are strings for FCM
          const sanitizedData = ensureStringData({
            communityId,
            eventId: event.id,
            type: 'reminder',
            subtype: 'contribution',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            senderName: 'KoFund Reminder',
            sentFromApp: 'true',
            notificationId: baseNotificationId,
          });

          const message = {
            notification: {
              title: reminderTitle,
              body: p.personalizedBody,
            },
            data: sanitizedData,
            tokens: combinedTokens,
            android: {
              priority: 'high',
              notification: {
                icon: 'ic_notification',
                color: '#764ba2',
              },
            },
            apns: {
              payload: {
                aps: {
                  contentAvailable: true,
                  badge: 1,
                  sound: 'default',
                },
              },
            },
          };
          
          const pushPromise = messaging.sendEachForMulticast(message)
            .then(response => {
              pushNotificationsSent += response.successCount;
              totalRemindersSent += response.successCount;
              
              if (response.failureCount > 0) {
                const invalidTokens = [];
                response.responses.forEach((resp, idx) => {
                  if (!resp.success && (resp.error?.code === 'messaging/registration-token-not-registered')) {
                    invalidTokens.push(combinedTokens[idx]);
                  }
                });
                if (invalidTokens.length > 0) {
                  return db.collection('users').doc(p.userId).update({
                    fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens)
                  });
                }
              }
            })
            .catch(err => console.error(`❌ Push failed for ${p.userId}:`, err.message));
          
          pushPromises.push(pushPromise);
        }
 
        if (pushPromises.length > 0) {
          await Promise.all(pushPromises);
          console.log(`✅ Total push notifications sent: ${pushNotificationsSent}`);
        }
        
        // 8. Record result for this event
        results.push({
          eventId: event.id,
          eventName: event.title,
          suggestedContribution,
          totalParticipants: participantsSnapshot.size,
          participantsNeedingReminders: participantsToRemind.length,
          notificationsCreated: eventNotificationsCreated,
          pushNotificationsSent,
        });
      }
      
      // 9. Return final results
      const result = {
        success: true,
        message: sendTest 
          ? `Test completed for ${eventId ? 'specific event' : 'all events'}` 
          : `Reminders sent for ${results.length} event(s)`,
        remindersSent: totalRemindersSent,
        notificationsCreated: totalNotificationsCreated,
        eventsProcessed: results.length,
        eventResults: results,
        communityId,
        communityName,
        isTest: sendTest,
        timestamp: now.toISOString(),
      };
      
      console.log("✅ sendeventContributionReminders completed successfully");
      console.log(`📊 Summary: ${totalNotificationsCreated} notifications created, ${totalRemindersSent} push notifications sent`);
      
      return result;
      
    } catch (error) {
      console.error("❌ Error in sendeventContributionReminders:", error);
      // Re-throw HttpsError as-is so client gets proper error code/message
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", `Failed to send contribution reminders: ${error.message}`);
    }
  }
);



// ==================== SCHEDULED CONTRIBUTION REMINDERS ====================

exports.runScheduledContributionReminders = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "Asia/Kolkata",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const now = new Date();
    const dueEventsSnapshot = await db
      .collection('events')
      .where('enableAutoReminders', '==', true)
      .where('status', '==', 'active')
      .where('nextReminderDate', '<=', admin.firestore.Timestamp.fromDate(now))
      .limit(100)
      .get();

    if (dueEventsSnapshot.empty) {
      console.log('No due contribution reminders found');
      return null;
    }

    let totalEventsProcessed = 0;
    let totalNotificationsCreated = 0;
    let totalPushNotificationsSent = 0;

    for (const eventDoc of dueEventsSnapshot.docs) {
      const event = { id: eventDoc.id, ...eventDoc.data() };
      const communityId = event.communityId;
      const suggestedContribution = parseFloat(event.suggestedContribution) || 0;

      if (!communityId || suggestedContribution <= 0) {
        continue;
      }

      const baseNotificationId = `${now.getTime()}_scheduled_${event.id}`;
      const communityUsersSnapshot = await db
        .collection('users')
        .where('communityId', '==', communityId)
        .where('isApproved', '==', true)
        .get();

      const userMap = new Map();
      communityUsersSnapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.isVirtualUser === true) return;
        userMap.set(doc.id, userData);
      });

      const communityTokensSnapshot = await db
        .collection('user_notification_tokens')
        .where('isActive', '==', true)
        .where('communityIds', 'array-contains', communityId)
        .get();

      const userTokensMap = new Map();
      communityTokensSnapshot.forEach(doc => {
        const tokenData = doc.data();
        if (!userMap.has(tokenData.userId) || !tokenData.token) return;
        if (!userTokensMap.has(tokenData.userId)) {
          userTokensMap.set(tokenData.userId, new Set());
        }
        userTokensMap.get(tokenData.userId).add(tokenData.token);
      });

      const allContributionsSnapshot = await db
        .collection('contributions')
        .where('eventId', '==', event.id)
        .where('status', '==', 'completed')
        .get();

      const userContributionsMap = new Map();
      allContributionsSnapshot.forEach(doc => {
        const contribution = doc.data();
        const amount = parseFloat(contribution.amount) || 0;
        userContributionsMap.set(contribution.userId, (userContributionsMap.get(contribution.userId) || 0) + amount);
      });

      const participantsSnapshot = await db
        .collection('participants')
        .where('eventId', '==', event.id)
        .where('status', '==', 'joined')
        .get();

      const participantsToRemind = [];
      const processedUserIds = new Set();

      for (const participantDoc of participantsSnapshot.docs) {
        const participant = participantDoc.data();
        const userId = participant.userId;
        if (!userId || processedUserIds.has(userId)) continue;
        processedUserIds.add(userId);

        const userData = userMap.get(userId);
        if (!userData) continue;

        const totalPaid = userContributionsMap.get(userId) || 0;
        const amountRemaining = Math.max(0, suggestedContribution - totalPaid);
        if (amountRemaining <= 0) continue;

        participantsToRemind.push({
          userId,
          userData,
          userName: userData.displayName || participant.userName || 'User',
          amountRemaining,
          body: `Hi ${userData.displayName || participant.userName || 'User'}, you have ?${amountRemaining.toFixed(0)} remaining for ${event.title}.`,
        });
      }

      if (participantsToRemind.length === 0) {
        await updateEventNextReminderDate(eventDoc.ref, event);
        continue;
      }

      const reminderTitle = event.customReminderTitle || `Contribution Reminder: ${event.title}`;
      const batch = db.batch();
      let eventNotificationsCreated = 0;

      for (const participant of participantsToRemind) {
        const notificationId = `${baseNotificationId}_${participant.userId}`;
        const body = event.customReminderMessage || participant.body;
        const notificationRef = db
          .collection('users')
          .doc(participant.userId)
          .collection('notifications')
          .doc(notificationId);

        batch.set(notificationRef, {
          id: notificationId,
          title: reminderTitle,
          body,
          type: 'reminder',
          subtype: 'contribution',
          priority: 'high',
          data: {
            communityId,
            eventId: event.id,
            eventName: event.title,
            amountRemaining: participant.amountRemaining,
            suggestedContribution,
            sentFromApp: true,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            notificationId: baseNotificationId,
          },
          userId: participant.userId,
          communityId,
          eventId: event.id,
          senderName: 'KoFund Reminder',
          isRead: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          deepLink: `/events/${event.id}/contribute`,
        });
        eventNotificationsCreated++;
      }

      await batch.commit();
      totalNotificationsCreated += eventNotificationsCreated;

      let eventPushSent = 0;
      for (const participant of participantsToRemind) {
        const tokensFromDoc = participant.userData.fcmTokens || [];
        const tokensFromCollection = userTokensMap.get(participant.userId) || new Set();
        const tokens = [...new Set([...tokensFromDoc, ...Array.from(tokensFromCollection)])]
          .filter(token => typeof token === 'string' && token.length >= 50);

        if (tokens.length === 0) continue;

        const body = event.customReminderMessage || participant.body;
        const response = await messaging.sendEachForMulticast({
          notification: { title: reminderTitle, body },
          data: ensureStringData({
            communityId,
            eventId: event.id,
            type: 'reminder',
            subtype: 'contribution',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            senderName: 'KoFund Reminder',
            sentFromApp: 'true',
            notificationId: baseNotificationId,
          }),
          tokens,
          android: {
            priority: 'high',
            notification: { icon: 'ic_notification', color: '#764ba2' },
          },
          apns: {
            payload: { aps: { contentAvailable: true, badge: 1, sound: 'default' } },
          },
        });
        eventPushSent += response.successCount;
      }

      totalPushNotificationsSent += eventPushSent;
      totalEventsProcessed++;
      await updateEventNextReminderDate(eventDoc.ref, event);
    }

    console.log(`Scheduled reminders processed ${totalEventsProcessed} events, created ${totalNotificationsCreated} notifications, sent ${totalPushNotificationsSent} pushes`);
    return null;
  }
);

async function updateEventNextReminderDate(eventRef, event) {
  const now = new Date();
  const candidateSendDates = [];

  const reminderDates = event.contributionReminderDates || [];
  for (const timestamp of reminderDates) {
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    if (date > now) candidateSendDates.push(date);
  }

  if (event.firstPaymentDueDate) {
    let currentDueDate = event.firstPaymentDueDate.toDate ? event.firstPaymentDueDate.toDate() : new Date(event.firstPaymentDueDate);
    const reminderDaysBefore = Number.isFinite(event.reminderDaysBefore) ? event.reminderDaysBefore : 7;
    const frequency = event.reminderFrequency || 'monthly';

    for (let safeguard = 0; safeguard < 24; safeguard++) {
      const sendDate = new Date(currentDueDate);
      sendDate.setDate(sendDate.getDate() - reminderDaysBefore);

      if (sendDate > now) {
        candidateSendDates.push(sendDate);
        break;
      }

      if (frequency === 'daily') {
        currentDueDate.setDate(currentDueDate.getDate() + 1);
      } else if (frequency === 'weekly') {
        currentDueDate.setDate(currentDueDate.getDate() + 7);
      } else if (frequency === 'monthly') {
        currentDueDate = new Date(currentDueDate.getFullYear(), currentDueDate.getMonth() + 1, currentDueDate.getDate());
      } else {
        break;
      }
    }
  }

  candidateSendDates.sort((a, b) => a.getTime() - b.getTime());
  const updates = {
    lastReminderSent: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (candidateSendDates.length > 0) {
    updates.nextReminderDate = admin.firestore.Timestamp.fromDate(candidateSendDates[0]);
  } else {
    updates.nextReminderDate = admin.firestore.FieldValue.delete();
  }

  await eventRef.update(updates);
}
// ==================== GLOBAL NOTIFICATION FUNCTION ====================

/**
 * Send notification to ALL active users
 * Use with caution - can be expensive for large user bases
 */
exports.sendGlobalNotification = onCall(
  {
    region: "us-central1",
    cors: true,
    timeoutSeconds: 120,
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      const { data, auth } = request;

      if (!auth) throw new Error("Authentication required");

      const senderDoc = await db.collection('users').doc(auth.uid).get();
      if (!senderDoc.exists || senderDoc.data().role !== 'admin') {
        throw new Error("Admin access required for global broadcast");
      }

      const { title, body, data: notificationData = {} } = data || {};
      if (!title || !body) throw new Error("Missing title or body");

      const now = new Date();
      const baseNotificationId = `global_${now.getTime()}`;

      const usersSnapshot = await db
        .collection('users')
        .where('isApproved', '==', true)
        .get();

      const realUsers = usersSnapshot.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .filter(user => user.isVirtualUser !== true);

      const realUserIds = new Set(realUsers.map(user => user.id));
      const tokens = [];
      const seenTokens = new Set();

      for (const user of realUsers) {
        const fcmTokens = user.fcmTokens || [];
        for (const token of fcmTokens) {
          if (typeof token === 'string' && token.length >= 50 && !seenTokens.has(token)) {
            tokens.push(token);
            seenTokens.add(token);
          }
        }
      }

      const tokensSnapshot = await db
        .collection('user_notification_tokens')
        .where('isActive', '==', true)
        .get();

      for (const tokenDoc of tokensSnapshot.docs) {
        const tokenData = tokenDoc.data();
        const token = tokenData.token;
        const userId = tokenData.userId;
        if (!realUserIds.has(userId)) continue;
        if (typeof token === 'string' && token.length >= 50 && !seenTokens.has(token)) {
          tokens.push(token);
          seenTokens.add(token);
        }
      }

      const notificationsBatch = db.batch();
      let notificationsCreated = 0;

      for (const user of realUsers) {
        const notificationId = `${baseNotificationId}_${user.id}`;
        const notificationRef = db
          .collection('users')
          .doc(user.id)
          .collection('notifications')
          .doc(notificationId);

        notificationsBatch.set(notificationRef, {
          id: notificationId,
          title,
          body,
          type: 'system',
          priority: 'normal',
          data: {
            ...notificationData,
            userId: user.id,
            type: 'system',
            senderId: auth.uid,
            senderName: 'KoFund',
            sentFromApp: true,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            notificationId: baseNotificationId,
            timestamp: now.toISOString(),
          },
          userId: user.id,
          communityId: user.communityId || null,
          eventId: null,
          isRead: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          deepLink: notificationData.deepLink || null,
          senderName: 'KoFund',
          senderId: auth.uid,
        });
        notificationsCreated++;
      }

      if (notificationsCreated > 0) {
        await notificationsBatch.commit();
      }

      let sentCount = 0;
      for (let index = 0; index < tokens.length; index += 500) {
        const chunk = tokens.slice(index, index + 500);
        const sanitizedData = ensureStringData({
          ...notificationData,
          type: 'system',
          sentFromApp: 'true',
          notificationId: baseNotificationId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          title,
          body,
        });

        const message = {
          notification: { title, body },
          data: sanitizedData,
          tokens: chunk,
          android: {
            priority: 'high',
            notification: { icon: 'ic_notification', color: '#764ba2' },
          },
        };
        const response = await messaging.sendEachForMulticast(message);
        sentCount += response.successCount;
      }

      return {
        success: true,
        sentCount,
        notificationsCreated,
        message: `Global notification saved for ${notificationsCreated} users and sent to ${sentCount} devices`,
      };
    } catch (error) {
      console.error("Error in sendGlobalNotification:", error);
      throw new Error(`Failed: ${error.message}`);
    }
  }
);
// ==================== TARGETED NOTIFICATION FUNCTION ====================

/**
 * Send notification to a specific list of user IDs
 */
exports.sendTargetedNotifications = onCall(
  {
    region: "us-central1",
    cors: true,
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      const { data, auth } = request;
      if (!auth) throw new Error("Authentication required");

      const { userIds, title, body, data: notificationData = {} } = data || {};
      if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
        throw new Error("Missing userIds list");
      }
      if (!title || !body) throw new Error("Missing title or body");

      const senderDoc = await db.collection('users').doc(auth.uid).get();
      if (!senderDoc.exists) throw new Error("Sender not found");
      if (senderDoc.data().role !== 'admin') {
        throw new HttpsError("permission-denied", "Only admins can send targeted notifications");
      }

      const now = new Date();
      const baseNotificationId = `target_${now.getTime()}`;
      const requestedUserIds = [...new Set(userIds.map(id => String(id)).filter(Boolean))].slice(0, 30);

      const usersSnapshot = await db
        .collection('users')
        .where(admin.firestore.FieldPath.documentId(), 'in', requestedUserIds)
        .get();

      const realUsers = usersSnapshot.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .filter(user => user.isApproved === true && user.isVirtualUser !== true);

      const realUserIds = new Set(realUsers.map(user => user.id));
      const tokens = [];
      const seenTokens = new Set();

      for (const user of realUsers) {
        const fcmTokens = user.fcmTokens || [];
        for (const token of fcmTokens) {
          if (typeof token === 'string' && token.length >= 50 && !seenTokens.has(token)) {
            tokens.push(token);
            seenTokens.add(token);
          }
        }
      }

      const tokensSnapshot = await db
        .collection('user_notification_tokens')
        .where('userId', 'in', requestedUserIds)
        .where('isActive', '==', true)
        .get();

      for (const tokenDoc of tokensSnapshot.docs) {
        const tokenData = tokenDoc.data();
        const token = tokenData.token;
        const userId = tokenData.userId;
        if (!realUserIds.has(userId)) continue;
        if (typeof token === 'string' && token.length >= 50 && !seenTokens.has(token)) {
          tokens.push(token);
          seenTokens.add(token);
        }
      }

      const notificationsBatch = db.batch();
      let notificationsCreated = 0;

      for (const user of realUsers) {
        const notificationId = `${baseNotificationId}_${user.id}`;
        const notificationRef = db
          .collection('users')
          .doc(user.id)
          .collection('notifications')
          .doc(notificationId);

        notificationsBatch.set(notificationRef, {
          id: notificationId,
          title,
          body,
          type: 'system',
          priority: 'normal',
          data: {
            ...notificationData,
            userId: user.id,
            type: 'system',
            senderId: auth.uid,
            senderName: 'KoFund',
            sentFromApp: true,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            notificationId: baseNotificationId,
            timestamp: now.toISOString(),
          },
          userId: user.id,
          communityId: user.communityId || null,
          eventId: null,
          isRead: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          deepLink: notificationData.deepLink || null,
          senderName: 'KoFund',
          senderId: auth.uid,
        });
        notificationsCreated++;
      }

      if (notificationsCreated > 0) {
        await notificationsBatch.commit();
      }

      let sentCount = 0;
      if (tokens.length > 0) {
        const sanitizedData = ensureStringData({
          ...notificationData,
          type: 'system',
          sentFromApp: 'true',
          notificationId: baseNotificationId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          title,
          body,
        });

        const message = {
          notification: { title, body },
          data: sanitizedData,
          tokens,
          android: {
            priority: 'high',
            notification: { icon: 'ic_notification', color: '#764ba2' },
          },
        };

        const response = await messaging.sendEachForMulticast(message);
        sentCount = response.successCount;
      }

      return {
        success: true,
        sentCount,
        notificationsCreated,
        message: `Targeted notification saved for ${notificationsCreated} users and sent to ${sentCount} devices`,
      };
    } catch (error) {
      console.error("Error in sendTargetedNotifications:", error);
      throw new Error(`Failed: ${error.message}`);
    }
  }
);
/**
 * Support / Help page
 * GET /support
 */
exports.support = functions.https.onRequest((req, res) => {
  if (req.method !== 'GET') {
    return res.status(405).send('Method Not Allowed');
  }
  const templates = require('./templates');
  res.setHeader('Content-Type', 'text/html');
  return res.status(200).send(templates.getSupportHtml());
});

/**
 * Data Safety page
 * GET /dataSafety
 */
exports.dataSafety = functions.https.onRequest((req, res) => {
  if (req.method !== 'GET') {
    return res.status(405).send('Method Not Allowed');
  }
  const templates = require('./templates');
  res.setHeader('Content-Type', 'text/html');
  return res.status(200).send(templates.getDataSafetyHtml());
});

/**
 * About KoFund page
 * GET /about
 */
exports.about = functions.https.onRequest((req, res) => {
  if (req.method !== 'GET') {
    return res.status(405).send('Method Not Allowed');
  }
  const templates = require('./templates');
  res.setHeader('Content-Type', 'text/html');
  return res.status(200).send(templates.getAboutHtml());
});

/**
 * Delete Account Page
 * GET /deleteAccount  — renders the interactive HTML form
 */
exports.deleteAccount = functions.https.onRequest((req, res) => {
  if (req.method !== 'GET') {
    return res.status(405).send('Method Not Allowed');
  }
  // Derive the base URL so the form can POST to deleteAccountData
  const baseUrl = `${req.protocol}://${req.hostname}`;
  const templates = require('./templates');
  res.setHeader('Content-Type', 'text/html');
  return res.status(200).send(templates.getDeleteAccountHtml(baseUrl));
});

/**
 * Delete Account Data (API)
 * POST /deleteAccountData
 * Body: { email: string, uid?: string }
 *
 * Deletes the user's DOCUMENTS from the `users` Firestore collection.
 * Also deactivates their FCM tokens and removes in-app notifications.
 * Does NOT delete the Firebase Authentication account.
 */
exports.deleteAccountData = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  try {
    const { email, uid } = req.body || {};

    if (!email || typeof email !== 'string') {
      return res.status(400).json({ error: 'Email address is required.' });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email.trim())) {
      return res.status(400).json({ error: 'Invalid email address format.' });
    }

    const sanitizedEmail = email.trim().toLowerCase();
    console.log(`🗑️ Delete account data request for email: ${sanitizedEmail}, uid: ${uid || 'not provided'}`);

    // ── 1. Find user document(s) by email (or uid if provided) ──
    let userDocs = [];

    if (uid && typeof uid === 'string' && uid.trim().length > 0) {
      // Try direct UID lookup first
      const directDoc = await db.collection('users').doc(uid.trim()).get();
      if (directDoc.exists) {
        const data = directDoc.data();
        // Verify email matches for security
        if ((data.email || '').toLowerCase() === sanitizedEmail) {
          userDocs = [directDoc];
          console.log(`✅ Found user by UID: ${uid.trim()}`);
        } else {
          console.log(`⚠️ UID ${uid.trim()} found but email doesn't match. Falling back to email search.`);
        }
      }
    }

    // Fallback: search by email
    if (userDocs.length === 0) {
      const emailQuery = await db
        .collection('users')
        .where('email', '==', sanitizedEmail)
        .limit(5)
        .get();

      if (!emailQuery.empty) {
        userDocs = emailQuery.docs;
        console.log(`✅ Found ${userDocs.length} user doc(s) by email: ${sanitizedEmail}`);
      }
    }

    if (userDocs.length === 0) {
      // No user found — still return success to avoid leaking info,
      // but log it so we can investigate
      console.log(`ℹ️ No user found for email: ${sanitizedEmail}. Returning success.`);
      return res.status(200).json({
        success: true,
        message: 'If an account with this email exists, its data has been queued for deletion.',
        deletedCount: 0,
      });
    }

    let totalDeleted = 0;

    for (const userDoc of userDocs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      console.log(`🗑️ Processing deletion for userId: ${userId}`);

      const batch = db.batch();

      // ── 2. Deactivate all FCM tokens for this user ──
      const tokenSnapshot = await db
        .collection('user_notification_tokens')
        .where('userId', '==', userId)
        .get();

      for (const tokenDoc of tokenSnapshot.docs) {
        batch.update(tokenDoc.ref, {
          isActive: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          deactivatedReason: 'account_deleted_by_user',
        });
      }
      console.log(`   📱 Deactivating ${tokenSnapshot.size} FCM token(s)`);

      // ── 3. Delete in-app notifications subcollection ──
      const notificationsSnapshot = await db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .limit(500)
        .get();

      for (const notifDoc of notificationsSnapshot.docs) {
        batch.delete(notifDoc.ref);
      }
      console.log(`   🔔 Deleting ${notificationsSnapshot.size} notification(s)`);

      // ── 4. Anonymize / delete the user document itself ──
      // We replace personal data with anonymized placeholders
      // rather than hard-deleting, to preserve community integrity
      batch.update(userDoc.ref, {
        displayName: 'Deleted User',
        email: `deleted_${userId}@kofund.deleted`,
        phoneNumber: null,
        photoUrl: null,
        fcmTokens: [],
        isDeleted: true,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        deletionRequestEmail: sanitizedEmail,
        // Clear sensitive fields
        notificationCommunities: [],
      });

      await batch.commit();
      totalDeleted++;
      console.log(`✅ Successfully anonymized userId: ${userId}`);

      // ── 5. Log the deletion request for audit trail ──
      await db.collection('account_deletion_requests').add({
        userId,
        email: sanitizedEmail,
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        tokensDeactivated: tokenSnapshot.size,
        notificationsDeleted: notificationsSnapshot.size,
        status: 'completed',
        note: 'User document anonymized. Firebase Auth account NOT deleted. Contact support for full deletion.',
      });
    }

    console.log(`✅ Account data deletion completed. Processed ${totalDeleted} user(s).`);

    return res.status(200).json({
      success: true,
      message: 'Your account data has been successfully removed from our systems.',
      deletedCount: totalDeleted,
      note: 'Historical contribution records in shared communities are retained for transparency. Contact kofundapp@gmail.com for complete account removal including Firebase Authentication.',
    });

  } catch (error) {
    console.error('❌ Error in deleteAccountData:', error);
    return res.status(500).json({
      error: 'An unexpected error occurred. Please try again or contact support at kofundapp@gmail.com',
    });
  }
});

