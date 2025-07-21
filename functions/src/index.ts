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