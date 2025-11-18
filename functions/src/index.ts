// functions/src/index.ts
/**
 Set Your Secret Key (If you haven't already): Open your terminal at the root of your Flutter project and run this command. This is a one-time setup.
 Generated bash
 firebase functions:config:set paystack.secret="YOUR_PAYSTACK_SECRET_KEY"
 Use code with caution.
 Bash
 (Replace with your actual key starting with sk_...)
 Deploy: From the same terminal, deploy the functions to Firebase.
 Generated bash
 firebase deploy --only functions
 */
// functions/src/index.ts

// functions/src/index.ts
// functions/src/index.ts

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as https from "https";
// --- FIX: Import the 'defineString' function for environment variables ---
import { defineString } from "firebase-functions/params";
// --- Import for scheduled functions ---
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();

// --- FIX: Define the environment variable. It will be loaded automatically on deploy. ---
const paystackSecret = defineString("PAYSTACK_SECRET");


// --- Interfaces for our expected data (no changes here) ---
interface InitializePaymentData {
  email: string;
  amount: number;
}

interface VerifyPaymentData {
  reference: string;
}

interface DeleteUserData {
  uid: string;
}

// --- Paystack Payment Functions (with updated syntax) ---

export const initializePayment = functions.https.onCall(
  async (request: functions.https.CallableRequest<InitializePaymentData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "The function must be called by an authenticated user.");
    }

    const email = request.data.email;
    const amount = request.data.amount;

    if (!email || !amount) {
      throw new functions.https.HttpsError("invalid-argument", "The function must be called with 'email' and 'amount' arguments.");
    }

    const postData = JSON.stringify({ "email": email, "amount": amount });

    const options = {
      hostname: "api.paystack.co",
      port: 443,
      path: "/transaction/initialize",
      method: "POST",
      headers: {
        // --- FIX: Use .value() to get the value from the defined variable ---
        "Authorization": `Bearer ${paystackSecret.value()}`,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
      },
    };

    return new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        let responseData = "";
        res.on("data", (chunk) => { responseData += chunk; });
        res.on("end", () => {
          console.log("Paystack Initialize Response:", responseData);
          resolve(JSON.parse(responseData));
        });
      });
      req.on("error", (e) => {
        console.error("Problem with Paystack request:", e);
        reject(new functions.https.HttpsError("internal", "Paystack API request failed."));
      });
      req.write(postData);
      req.end();
    });
  });


export const verifyPayment = functions.https.onCall(
  async (request: functions.https.CallableRequest<VerifyPaymentData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "The function must be called by an authenticated user.");
    }

    const reference = request.data.reference;

    if (!reference) {
      throw new functions.https.HttpsError("invalid-argument", "The function must be called with a 'reference' argument.");
    }

    const options = {
      hostname: "api.paystack.co",
      port: 443,
      path: `/transaction/verify/${reference}`,
      method: "GET",
      headers: {
          // --- FIX: Use .value() to get the value from the defined variable ---
          "Authorization": `Bearer ${paystackSecret.value()}`
      },
    };

    return new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        let responseData = "";
        res.on("data", (chunk) => { responseData += chunk; });
        res.on("end", () => {
          console.log("Paystack Verify Response:", responseData);
          resolve(JSON.parse(responseData));
        });
      });
      req.on("error", (e) => {
        console.error("Problem with Paystack verification:", e);
        reject(new functions.https.HttpsError("internal", "Paystack verification request failed."));
      });
      req.end();
    });
  });


// --- User Deletion Function (Unchanged, already good) ---
export const deleteUser = functions.https.onCall(
  async (request: functions.https.CallableRequest<DeleteUserData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "The function must be called by an authenticated user.");
    }
    const uid = request.data.uid;
    if (!uid || typeof uid !== "string") {
      throw new functions.https.HttpsError("invalid-argument", "The function must be called with a 'uid' string.");
    }
    try {
      await admin.auth().deleteUser(uid);
      console.log(`Successfully deleted auth user ${uid}.`);
      await admin.firestore().collection("Staff").doc(uid).delete();
      console.log(`Successfully deleted firestore user ${uid}.`);
      return { message: `Successfully deleted user ${uid}.` };
    } catch (error) {
      console.error("Error deleting user:", error);
      if (error instanceof functions.https.HttpsError) { throw error; }
      throw new functions.https.HttpsError("unknown", "An unexpected error occurred.");
    }
  });

// --- Scheduled Function to Reset Annual Leave Balances ---
export const resetAnnualLeave = onSchedule({
  schedule: "0 0 1 10 *",
  timeZone: "Africa/Lagos"
}, async (event) => {
  console.log("Starting annual leave reset for all staff on October 1st.");

  try {
    // Get all staff documents
    const staffCollection = admin.firestore().collection('Staff');
    const staffSnapshot = await staffCollection.get();

    const batch = admin.firestore().batch();
    let resetCount = 0;

    for (const staffDoc of staffSnapshot.docs) {
      const staffData = staffDoc.data();
      const gender = staffData['gender'] as string;
      const staffId = staffDoc.id;

      // Determine leave balances based on gender
      const annualLeave = 10;
      const maternityLeave = (gender === 'Female') ? 30 : 0;
      const paternityLeave = 0; // Not used as per code
      const holidayLeave = 0;

      // Reference to RemainingLeave document
      const remainingLeaveRef = staffCollection.doc(staffId).collection('RemainingLeave').doc('remainingLeaveDoc');

      // Update the document
      batch.set(remainingLeaveRef, {
        staffId: staffId,
        annualLeaveBalance: annualLeave,
        maternityLeaveBalance: maternityLeave,
        paternityLeaveBalance: paternityLeave,
        holidayLeaveBalance: holidayLeave,
        dateUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      resetCount++;
      console.log(`Prepared reset for staff: ${staffId} (${gender})`);
    }

    // Commit the batch
    await batch.commit();

    console.log(`Annual leave reset completed for ${resetCount} staff members.`);
  } catch (error) {
    console.error("Error resetting annual leave:", error);
    throw new Error("Failed to reset annual leave balances.");
  }
});