import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * Deletes a user from Firebase Authentication and their corresponding
 * document in the 'Staff' collection in Firestore.
 */
export const deleteUser = functions.https.onCall(async (data, context) => {
  // Check if the user calling the function is authenticated.
  // In a real app, you would also check for admin custom claims here.
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called by an authenticated user."
    );
  }

  // Safely access the UID from the data payload
  const uid = data.uid;

  if (!uid || typeof uid !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a 'uid' string in the data payload."
    );
  }

  try {
    // 1. Delete user from Firebase Authentication
    await admin.auth().deleteUser(uid);
    console.log(`Successfully deleted auth user ${uid}.`);

    // 2. Delete user's document from Firestore
    await admin.firestore().collection("Staff").doc(uid).delete();
    console.log(`Successfully deleted firestore user ${uid}.`);

    return {
      message: `Successfully deleted user ${uid}.`,
    };
  } catch (error) {
    console.error("Error deleting user:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "unknown",
      "An unexpected error occurred while deleting the user."
    );
  }
});