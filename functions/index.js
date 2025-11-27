const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK if not already initialized
// This pattern is more robust for environments where init might be called multiple times
// (e.g., during local emulation reloads or in certain testing scenarios).
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();
const logger = functions.logger; // Use the provided logger for better structured logs

/**
 * Helper function to check if a user is an admin.
 * @param {string} userId The UID of the user to check.
 * @return {Promise<boolean>} True if the user is an admin, false otherwise.
 */
async function isAdminUser(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    return userDoc.exists && userDoc.data() && userDoc.data().isAdmin === true;
  } catch (error) {
    logger.error("Error checking admin status:", error);
    return false;
  }
}

/**
 * Cloud Function to send push notifications to all users (or specific users if implemented).
 * Triggered via HTTPS callable function from the admin panel.
 * @param {object} data The data sent from the client.
 * @param {string} data.title The title of the notification.
 * @param {string} data.body The body/content of the notification.
 * @param {string} [data.imageUrl] Optional URL for a notification image.
 * @param {object} [data.data] Optional custom data payload for the notification.
 * @param {functions.https.CallableContext} context The context of the call.
 * @return {Promise<object>} A promise that resolves to an object indicating success and results.
 */
exports.sendNotification = functions.https.onCall(async(data, context) => {
  // 1. Authentication and Authorization (Crucial for admin actions)
  if (!context.auth) {
    logger.warn("sendNotification: Unauthenticated call detected.");
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated.",
    );
  }

  const callingUserId = context.auth.uid;
  if (!(await isAdminUser(callingUserId))) {
    logger.warn(`sendNotification: User ${callingUserId} attempted to send
      notification but is not an admin.`);
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admin users can send notifications.",
    );
  }
  logger.info(`sendNotification: Admin user ${callingUserId} is initiating notification.`);


  // 2. Extract Data from Flutter Request
  const { title, body, imageUrl, data: notificationData } = data;

  if (!title || !body) {
    logger.error("sendNotification: Missing title or body in request data.");
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Notification title and body are required.",
    );
  }

  // 3. Fetch all valid FCM tokens from user documents
  const tokens = [];
  try {
    const usersSnapshot = await db.collection("users").get();
    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      if (
        userData.fcmToken &&
        typeof userData.fcmToken === "string" &&
        userData.fcmToken.length > 0
      ) {
        tokens.push(userData.fcmToken);
      }
    });
    logger.info(`sendNotification: Found ${tokens.length} FCM tokens.`);
  } catch (error) {
    logger.error("sendNotification: Error fetching FCM tokens:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to retrieve FCM tokens from database.",
      error.message,
    );
  }

  if (tokens.length === 0) {
    logger.warn(
      "sendNotification: No FCM tokens found to send notifications to." +
        " Returning success=true but no notifications sent.",
    );
    return { success: true, message: "No recipients found with valid FCM tokens." };
  }

  // 4. Construct FCM Message Payload
  const message = {
    notification: {
      title: title,
      body: body,
      ...(imageUrl && { imageUrl: imageUrl }), // Add imageUrl if present
    },
    data: {
      // Convert all notificationData map values to strings,
      // as FCM data payload only accepts strings.
      ...(notificationData &&
        Object.fromEntries(
          Object.entries(notificationData).map(([key, value]) => [key, String(value)]),
        )),
      // Add default data if needed, e.g., to indicate it's a general notification
      type: "general_admin_push",
    },
    tokens: tokens, // Target specific tokens
  };

  // 5. Send Notification
  try {
    const response = await messaging.sendEachForMulticast(message);
    logger.info("sendNotification: Successfully processed multicast message:", {
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

    // Optional: Handle failed tokens (e.g., remove them from your database if they are invalid)
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          logger.error(
            `sendNotification: Failed to send to token at index ${idx}:`,
            resp.error,
          );
          // Check for specific error codes that indicate an invalid/expired token
          if (
            resp.error &&
            (resp.error.code === "messaging/invalid-registration-token" ||
              resp.error.code === "messaging/registration-token-not-registered" ||
              resp.error.code === "messaging/unregistered")
          ) {
            invalidTokens.push(tokens[idx]);
          }
        }
      });

      if (invalidTokens.length > 0) {
        logger.warn(
          `sendNotification: Found ${invalidTokens.length} invalid FCM tokens.
            Initiating cleanup.`,
        );
        // --- Implement actual cleanup logic here ---
        // This is an example. You'd need to query your `users` collection
        // to find documents that contain these `invalidTokens` and then
        // update/delete their `fcmToken` field.
        // Example (this is a simplified illustration, optimize for production):
        const cleanupPromises = invalidTokens.map(async(invalidToken) => {
          try {
            const usersWithInvalidToken = await db.collection("users")
              .where("fcmToken", "==", invalidToken)
              .get();

            const batch = db.batch();
            usersWithInvalidToken.forEach((userDoc) => {
              logger.info(`Cleaning up token for user ${userDoc.id}: ${invalidToken}`);
              batch.update(userDoc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
            });
            await batch.commit();
            logger.info(`Successfully removed invalid token ${invalidToken}.`);
          } catch (cleanupError) {
            logger.error(
              `Error during cleanup for token ${invalidToken}:`,
              cleanupError,
            );
          }
        });
        await Promise.allSettled(cleanupPromises); // Use allSettled to ensure all attempts complete
        // --- End cleanup logic example ---
      }
    }

    return {
      success: true,
      message: "Notifications processing initiated.",
      results: {
        successCount: response.successCount,
        failureCount: response.failureCount,
      },
    };
  } catch (error) {
    logger.error("sendNotification: Error sending multicast notification:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to send notification via FCM.",
      error.message,
    );
  }
});

/**
 * Cloud Function to delete a user account securely.
 * This function bypasses client-side rules and directly interacts with Firebase Auth.
 * Triggered via HTTPS callable function from the admin panel.
 * @param {object} data The data sent from the client.
 * @param {string} data.uid The UID of the user account to delete.
 * @param {functions.https.CallableContext} context The context of the call.
 * @return {Promise<object>} A promise that resolves to an object indicating success.
 */
exports.deleteUserAccount = functions.https.onCall(async(data, context) => {
  // 1. Authentication and Authorization Check
  if (!context.auth) {
    logger.warn("deleteUserAccount: Unauthenticated call detected.");
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated.",
    );
  }

  const callingUserId = context.auth.uid;
  if (!(await isAdminUser(callingUserId))) {
    logger.warn(`deleteUserAccount: User ${callingUserId} attempted to delete user
      but is not an admin.`);
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admin users can delete other users.",
    );
  }
  logger.info(`deleteUserAccount: Admin user ${callingUserId} is initiating user
    deletion.`);


  // 2. Extract Data
  const uidToDelete = data.uid;

  if (!uidToDelete) {
    logger.error("deleteUserAccount: Missing UID in request data.");
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The target user UID is required.",
    );
  }

  // Prevent an admin from deleting their own account via this function for safety.
  if (uidToDelete === callingUserId) {
    logger.warn(
      `deleteUserAccount: Admin ${callingUserId} attempted to delete their own
        account. This is not allowed via admin panel function.`,
    );
    throw new functions.https.HttpsError(
      "permission-denied",
      "Admins cannot delete their own account via this function.",
    );
  }

  // 3. Delete user from Firebase Authentication
  try {
    await auth.deleteUser(uidToDelete);
    logger.info(`deleteUserAccount: Successfully deleted user ${uidToDelete} from
      Firebase Auth.`);

    // 4. Delete user's document from Firestore
    // This example only deletes the main user document.
    // For deleting subcollections (e.g., cart, orders), consider:
    // a) A separate recursive delete Cloud Function triggered by `onDelete` on the user doc.
    // b) Using the Firebase Admin SDK's `deleteCollection` (experimental, careful with large collections).
    // c) Batch deleting if subcollections are small and known.
    await db.collection("users").doc(uidToDelete).delete();
    logger.info(
      `deleteUserAccount: Successfully deleted user document ${uidToDelete} from
        Firestore.`,
    );

    return {
      success: true,
      message: `User ${uidToDelete} and their data deleted successfully.`,
    };
  } catch (error) {
    logger.error(`deleteUserAccount: Error deleting user ${uidToDelete}:`, error);
    // Categorize Firebase Auth errors for better client-side feedback
    if (error.code === "auth/user-not-found") {
      throw new functions.https.HttpsError(
        "not-found",
        "The user to be deleted was not found.",
      );
    }
    throw new functions.https.HttpsError(
      "internal",
      "Failed to delete user account.",
      error.message,
    );
  }
});
