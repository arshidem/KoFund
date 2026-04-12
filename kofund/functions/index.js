


/**
 * 
 * Cloud Functions for KoFund - v2 API
 * UPDATED FOR COMMUNITY-BASED NOTIFICATION SYSTEM
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
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

// ==================== TOKEN MANAGEMENT FUNCTIONS ====================

/**
 * Register FCM token with user and community context
 * ⭐ UPDATED: Uses new token storage structure
 */
exports.registerFCMToken = onCall(
  {
    region: "us-central1",
    cors: true,
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

// Remove duplicate 'api' function (you have two declarations)
exports.api = functions.https.onRequest((req, res) => {
  res.json({
    status: 'ok',
    message: 'KoFund API',
    timestamp: new Date().toISOString()
  });
});

// ===== ADD THIS NEW FUNCTION =====
exports.join = functions.https.onRequest((req, res) => {
  // Handle CORS
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  // Extract parameters from URL: /join/g5lik7kq4w2Tabza6Uwp?code=GH56F38H
  const pathParts = req.path.split('/');
  const inviteCode = pathParts[2]; // Gets "g5lik7kq4w2Tabza6Uwp"
  const verificationCode = req.query.code; // Gets "GH56F38H"
  
  // Log for debugging
  console.log('Join request:', { inviteCode, verificationCode });
  
  // Your business logic here
  // Example: Check Firestore for valid invite
  
  res.json({
    success: true,
    message: 'Join endpoint working',
    data: {
      invite_code: inviteCode,
      verification_code: verificationCode
    }
  });
});
/**
 * Unregister FCM token when user logs out
 */
exports.unregisterFCMToken = onCall(
  {
    region: "us-central1",
    cors: true,
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
    enforceAppCheck: false, // ⭐ Disable enforcement to bypass 403 error during dev
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
        programId = null,
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
      
      const isAuthorized = senderPrimaryCommunity === communityId || 
                          senderCommunities.includes(communityId);
      
      if (!isAuthorized) {
        console.error(`❌ Sender ${auth.uid} not authorized for community ${communityId}`);
        throw new HttpsError("permission-denied", "Sender is not a member of this community");
      }
      
      // 2. Get community info
      const communityDoc = await db.collection('communities').doc(communityId).get();
      
      if (!communityDoc.exists) {
        throw new Error("Community not found");
      }
      
      const communityData = communityDoc.data();
      const communityName = communityData.name || 'Community';
      
      // 3. ✅ RELIABLE: Directly query users collection by communityId
      // This uses a simple two-field compound query (communityId + isApproved)
      // no composite index required, and works for ALL community members.
      const communityMembersSnapshot = await db
        .collection('users')
        .where('communityId', '==', communityId)
        .where('isApproved', '==', true)
        .get();

      console.log(`👥 Found ${communityMembersSnapshot.size} approved members in community ${communityId}`);

      // Collect tokens and user info
      const allTokens = [];
      const tokenToUserMap = new Map();
      const usersToNotify = new Set(); // Track unique users

      for (const userDoc of communityMembersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();

        // Skip the sender (admin who created the program)
        if (userId === auth.uid) continue;

        // Skip virtual users
        if (userData.isVirtualUser === true) continue;

        // Collect all FCM tokens for this user
        const fcmTokens = userData.fcmTokens || [];
        for (const token of fcmTokens) {
          if (typeof token === 'string' && token.length >= 50) {
            allTokens.push(token);
            tokenToUserMap.set(token, userId);
            usersToNotify.add(userId);
          }
        }
      }

      // Remove duplicate tokens
      const uniqueTokens = [...new Set(allTokens)];
      console.log(`📱 Unique tokens to notify: ${uniqueTokens.length}`);
      console.log(`👥 Unique users to notify: ${usersToNotify.size}`);

      if (uniqueTokens.length === 0) {
        console.log(`⚠️ No FCM tokens found. Members may not have logged in or granted push permission.`);
        // Still create in-app notifications for all approved, non-virtual members
        for (const userDoc of communityMembersSnapshot.docs) {
          const userId = userDoc.id;
          const uData = userDoc.data();
          if (userId !== auth.uid && uData.isVirtualUser !== true) {
            usersToNotify.add(userId);
          }
        }
      }
      
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
        
        // Check if notification already exists
        const existingDoc = await notificationRef.get();
        if (existingDoc.exists) {
          console.log(`⚠️ Notification ${notificationId} already exists, skipping`);
          continue;
        }
        
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
            programId: programId || '',
            senderId: auth.uid,
            senderName: senderName || senderData.displayName || 'KoFund Member',
            sentFromApp: true,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            notificationId: baseNotificationId,
            timestamp: now.toISOString(),
          },
          userId: userId,
          communityId: communityId,
          programId: programId || null,
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
          
          const message = {
            data: {
              ...notificationData,
              communityId,
              type,
              programId: programId || '',
              senderId: auth.uid,
              senderName: senderName || senderData.displayName || 'KoFund Member',
              sentFromApp: 'true',
              notificationId: baseNotificationId,
              timestamp: now.toISOString(),
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              title: title,
              body: body,
            },
            tokens: tokenChunk,
            android: {
              priority: 'high',
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
                  category: 'program_announcement',
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
        programId = null,
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
      
      // 2. Check if notification already exists
      const existingNotification = await db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .get();
      
      if (existingNotification.exists) {
        console.log(`⚠️ Notification ${notificationId} already exists, skipping document creation`);
      } else {
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
            programId: programId || null,
            senderId: auth.uid,
            senderName: senderName || userData.displayName || 'KoFund',
            sentFromApp: true,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            notificationId: notificationId,
            timestamp: now.toISOString(),
          },
          userId: userId,
          communityId: communityId || userData.communityId || null,
          programId: programId || null,
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
        const message = {
          notification: {
            title: title,
            body: body,
          },
          data: {
            ...notificationData,
            userId: userId,
            communityId: communityId || userData.communityId || '',
            type: type,
            programId: programId || '',
            senderId: auth.uid,
            senderName: senderName || 'KoFund',
            sentFromApp: 'true',
            notificationId: notificationId,
            timestamp: now.toISOString(),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            title: title,
            body: body,
          },
          tokens: uniqueTokens,
          android: {
            priority: 'high',
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
 * Send contribution reminders to users in a community/program
 * ⭐ UPDATED: Uses new token structure
 */
exports.sendProgramContributionReminders = onCall(
  {
    region: "us-central1",
    cors: true,
    timeoutSeconds: 60,
  },
  async (request) => {
    try {
      const { data, auth } = request;
      
      if (!auth) {
        throw new Error("Authentication required");
      }
      
      const { 
        communityId,
        programId = null,
        sendTest = false,
        testUserId = null,
      } = data || {};
      
      console.log("⏰ sendProgramContributionReminders called");
      console.log("Community:", communityId);
      console.log("Program:", programId || "All programs");
      
      if (!communityId) {
        throw new Error("Missing required field: communityId");
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
      
      // 2. Get target programs - FIXED: Programs in root 'programs' collection
      let programsSnapshot = [];
      
      if (programId) {
        // FIXED: Query root 'programs' collection
        const programDoc = await db.collection('programs').doc(programId).get();
        
        if (programDoc.exists) {
          const programData = programDoc.data();
          // Check if program belongs to this community
          if (programData.communityId === communityId && programData.status === 'active') {
            programsSnapshot = [programDoc];
          } else {
            return {
              success: true,
              message: "Program not found or not active in this community",
              remindersSent: 0,
              communityId,
              communityName,
              timestamp: now.toISOString(),
            };
          }
        } else {
          return {
            success: true,
            message: "Program not found",
            remindersSent: 0,
            communityId,
            communityName,
            timestamp: now.toISOString(),
          };
        }
      } else {
        // FIXED: Query root 'programs' collection
        const programsQuery = db
          .collection('programs')
          .where('communityId', '==', communityId)
          .where('status', '==', 'active');
        
        const querySnapshot = await programsQuery.get();
        programsSnapshot = querySnapshot.docs;
      }
      
      console.log(`📋 Found ${programsSnapshot.length} program(s) to process`);
      
      if (programsSnapshot.length === 0) {
        return {
          success: true,
          message: "No active programs found",
          remindersSent: 0,
          communityId,
          communityName,
          timestamp: now.toISOString(),
        };
      }
      
      const results = [];
      let totalRemindersSent = 0;
      let totalNotificationsCreated = 0;
      
      // 3. Process each program
      for (const programDoc of programsSnapshot) {
        const program = {
          id: programDoc.id,
          ...programDoc.data()
        };
        
        console.log(`\n🎯 Processing Program: ${program.title || program.id}`);
        
        // Check if program has reminder settings enabled
        if (!program.enableAutoReminders) {
          console.log(`⏭️ Skipping - auto reminders disabled`);
          continue;
        }
        
        const suggestedContribution = parseFloat(program.suggestedContribution) || 0;
        
        if (suggestedContribution <= 0) {
          console.log(`⏭️ Skipping - no suggested contribution amount`);
          continue;
        }
        
        console.log(`💰 Suggested contribution: ${suggestedContribution}`);
        
        // 4. Get all participants for this program - FIXED: Participants in root 'participants' collection
        const participantsSnapshot = await db
          .collection('participants')
          .where('programId', '==', program.id)
          .where('status', '==', 'joined')
          .get();
        
        console.log(`👥 Found ${participantsSnapshot.size} participants in program ${program.id}`);
        
        if (participantsSnapshot.size === 0) {
          continue;
        }
        
        // 5. Get users who need reminders
        const participantsToRemind = [];
        const processedUserIds = new Set();
        
        for (const participantDoc of participantsSnapshot.docs) {
          const participant = {
            id: participantDoc.id,
            ...participantDoc.data()
          };
          
          if (processedUserIds.has(participant.userId)) continue;
          processedUserIds.add(participant.userId);
          
          // Test mode filtering
          if (sendTest && testUserId && participant.userId !== testUserId) {
            continue;
          }
          
          // Get user info
          const userDoc = await db.collection('users').doc(participant.userId).get();
          if (!userDoc.exists) {
            console.log(`⏭️ Skipping - user ${participant.userId} not found`);
            continue;
          }
          
          const userData = userDoc.data();
          
          // Check eligibility - FIXED: Match your Flutter logic
          if (!userData.isApproved || userData.isVirtualUser === true) {
            console.log(`\u23EF\uFE0F Skipping - user ${participant.userId} not approved or is virtual`);
            continue;
          }
          
          if (userData.communityId !== communityId) {
            console.log(`⏭️ Skipping - user ${participant.userId} not in community`);
            continue;
          }
          
          // Calculate total paid for this program
          const contributionsSnapshot = await db
            .collection('contributions')
            .where('programId', '==', program.id)
            .where('userId', '==', participant.userId)
            .where('status', '==', 'completed') // Added status check
            .get();
          
          let totalPaid = 0;
          contributionsSnapshot.forEach((doc) => {
            const contribution = doc.data();
            const amount = parseFloat(contribution.amount) || 0;
            if (amount > 0) {
              totalPaid += amount;
            }
          });
          
          const amountRemaining = Math.max(0, suggestedContribution - totalPaid);
          const isFullyPaid = amountRemaining <= 0;
          
          if (!isFullyPaid) {
            participantsToRemind.push({
              participantId: participant.id,
              userId: participant.userId,
              userName: userData.displayName || participant.userName || 'User',
              userEmail: userData.email,
              totalPaid,
              amountRemaining,
              personalizedBody: `Hi ${userData.displayName || participant.userName || 'User'}, you have $${amountRemaining.toFixed(2)} remaining of your $${suggestedContribution.toFixed(2)} contribution for ${program.title}.`,
            });
            
            console.log(`🔔 User ${participant.userId} needs reminder: paid $${totalPaid.toFixed(2)}, remaining $${amountRemaining.toFixed(2)}`);
          } else {
            console.log(`✅ User ${participant.userId} already fully paid: $${totalPaid.toFixed(2)}`);
          }
        }
        
        console.log(`🔔 ${participantsToRemind.length} participants need reminders for program ${program.id}`);
        
        if (participantsToRemind.length === 0) {
          console.log(`⏭️ Skipping program - no participants need reminders`);
          continue;
        }
        
        // 6. Create notifications
        const reminderTitle = `⏰ Contribution Reminder: ${program.title}`;
        const batch = db.batch();
        let programNotificationsCreated = 0;
        
        for (const participant of participantsToRemind) {
          const { userId, userName, personalizedBody, amountRemaining } = participant;
          
          const notificationId = `${baseNotificationId}_reminder_${program.id}_${userId}`;
          
          // Check if notification already exists
          const existingNotification = await db
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId)
            .get();
          
          if (existingNotification.exists) {
            console.log(`⏭️ Skipping - notification already exists for user ${userId}`);
            continue;
          }
          
          // Create notification
          const notificationRef = db
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId);
          
          const notification = {
            id: notificationId,
            title: reminderTitle,
            body: personalizedBody,
            type: 'reminder',
            subtype: 'contribution',
            priority: 'high',
            data: {
              communityId,
              programId: program.id,
              programName: program.title,
              amountRemaining,
              suggestedContribution,
              senderId: auth.uid,
              sentFromApp: true,
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              notificationId: baseNotificationId,
            },
            userId,
            communityId,
            programId: program.id,
            senderName: 'KoFund Reminder',
            senderId: auth.uid,
            isRead: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            deepLink: `/programs/${program.id}/contribute`,
            metadata: {
              amountRemaining,
              suggestedContribution,
              userName,
            },
          };
          
          if (!sendTest) {
            batch.set(notificationRef, notification);
            programNotificationsCreated++;
          }
        }
        
        // Commit notifications batch
        if (!sendTest && programNotificationsCreated > 0) {
          await batch.commit();
          totalNotificationsCreated += programNotificationsCreated;
          console.log(`✅ Created ${programNotificationsCreated} notifications in Firestore`);
        }
        
        // 7. Send push notifications
        let pushNotificationsSent = 0;
        const pushPromises = [];
        
        for (const participant of participantsToRemind) {
          const { userId, personalizedBody } = participant;
          
          try {
            // Get user document
            const userDoc = await db.collection('users').doc(userId).get();
            
            if (!userDoc.exists) continue;
            
            const userData = userDoc.data();
            const fcmTokens = userData.fcmTokens || [];
            
            if (fcmTokens.length === 0) {
              console.log(`⚠️ No FCM tokens found for user ${userId}`);
              continue;
            }
            
            console.log(`📱 User ${userId} has ${fcmTokens.length} token(s)`);
            
            // Send to all tokens for this user
            const message = {
              notification: {
                title: reminderTitle,
                body: personalizedBody,
              },
              data: {
                communityId,
                programId: program.id,
                type: 'reminder',
                subtype: 'contribution',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                senderName: 'KoFund Reminder',
                sentFromApp: 'true',
                notificationId: baseNotificationId,
              },
              tokens: fcmTokens,
              android: {
                priority: 'high',
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
            
            // Send push notification
            const pushPromise = messaging.sendEachForMulticast(message)
              .then(response => {
                console.log(`✅ Sent to ${userId}: ${response.successCount} successful, ${response.failureCount} failed`);
                pushNotificationsSent += response.successCount;
                totalRemindersSent += response.successCount;
                
                // Clean invalid tokens
                if (response.failureCount > 0) {
                  const invalidTokens = [];
                  response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                      const failedToken = fcmTokens[idx];
                      console.log(`❌ Failed token ${failedToken.substring(0, 20)}...: ${resp.error?.message}`);
                      
                      if (resp.error?.code === 'messaging/registration-token-not-registered' ||
                          resp.error?.code === 'messaging/invalid-registration-token') {
                        invalidTokens.push(failedToken);
                      }
                    }
                  });
                  
                  // Remove invalid tokens from user's document
                  if (invalidTokens.length > 0) {
                    return db.collection('users').doc(userId).update({
                      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens)
                    }).then(() => {
                      console.log(`🗑️ Removed ${invalidTokens.length} invalid tokens from ${userId}`);
                    });
                  }
                }
              })
              .catch(error => {
                console.error(`❌ Error sending to ${userId}:`, error.message);
              });
            
            pushPromises.push(pushPromise);
            
          } catch (userError) {
            console.error(`❌ Error processing user ${userId}:`, userError.message);
          }
        }
        
        // Wait for all push notifications to be sent
        if (pushPromises.length > 0) {
          await Promise.all(pushPromises);
          console.log(`✅ Total push notifications sent: ${pushNotificationsSent}`);
        }
        
        // 8. Record result for this program
        results.push({
          programId: program.id,
          programName: program.title,
          suggestedContribution,
          totalParticipants: participantsSnapshot.size,
          participantsNeedingReminders: participantsToRemind.length,
          notificationsCreated: programNotificationsCreated,
          pushNotificationsSent,
        });
      }
      
      // 9. Return final results
      const result = {
        success: true,
        message: sendTest 
          ? `Test completed for ${programId ? 'specific program' : 'all programs'}` 
          : `Reminders sent for ${results.length} program(s)`,
        remindersSent: totalRemindersSent,
        notificationsCreated: totalNotificationsCreated,
        programsProcessed: results.length,
        programResults: results,
        communityId,
        communityName,
        isTest: sendTest,
        timestamp: now.toISOString(),
      };
      
      console.log("✅ sendProgramContributionReminders completed successfully");
      console.log(`📊 Summary: ${totalNotificationsCreated} notifications created, ${totalRemindersSent} push notifications sent`);
      
      return result;
      
    } catch (error) {
      console.error("❌ Error in sendProgramContributionReminders:", error);
      throw new Error(`Failed to send contribution reminders: ${error.message}`);
    }
  }
);

// ==================== HELPER FUNCTIONS ====================

/**
 * Simple test function to verify Cloud Functions are working
 */
exports.testKoFund = onCall(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    try {
      console.log("🧪 testKoFund called");
      
      return {
        success: true,
        message: "KoFund Cloud Functions v2 are working! 🎉",
        functions: {
          version: "2.0.0",
          region: "us-central1",
          status: "active",
          timestamp: new Date().toISOString(),
        },
        notificationSystem: {
          structure: "community-based",
          tokenStorage: "user_notification_tokens collection",
          features: ["community-targeting", "sender-exclusion", "token-cleanup"],
        },
      };
      
    } catch (error) {
      console.error("❌ testKoFund error:", error);
      throw new Error(`Test failed: ${error.message}`);
    }
  }
);