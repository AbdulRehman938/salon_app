import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import Stripe from "stripe";

setGlobalOptions({maxInstances: 10});
initializeApp();

type SendOtpPayload = {
  email?: string;
  sixDigitCode?: string;
};

type OnlineCheckoutDraftPayload = {
  salonId?: string;
  salonName?: string;
  bookingDateIso?: string;
  bookingTime?: string;
  stylistLabel?: string;
  services?: Array<{name?: string; price?: number}>;
  discountAmount?: number;
  totalAmount?: number;
};

type DemoPaymentPayload = {
  draft?: OnlineCheckoutDraftPayload;
  paymentMethodType?: string;
  selectedCard?: {brand?: string; last4?: string};
};

export const sendOtpEmail = onCall(async (request) => {
  const data = (request.data ?? {}) as SendOtpPayload;
  const email = (data.email ?? "").trim();
  const sixDigitCode = (data.sixDigitCode ?? "").trim();

  if (email.length === 0 || sixDigitCode.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "email and sixDigitCode are required.",
    );
  }

  validateEmail(email);
  validateOtp(sixDigitCode);

  const brevoApiKey = process.env.BREVO_API_KEY;
  if (!brevoApiKey) {
    throw new HttpsError(
      "failed-precondition",
      "BREVO_API_KEY is not configured in environment variables.",
    );
  }

  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "accept": "application/json",
      "api-key": brevoApiKey,
    },
    body: JSON.stringify({
      sender: {
        name: "Salon App",
        email: "no-reply@salonapp-3ba4c.firebaseapp.com",
      },
      to: [{email}],
      subject: "Your Salon App OTP",
      htmlContent: buildOtpHtml(sixDigitCode),
    }),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new HttpsError(
      "internal",
      "Failed to send OTP email via Brevo.",
      {status: response.status, details},
    );
  }

  return {success: true, message: "OTP email sent successfully."};
});

export const createDemoOnlinePayment = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be signed in.");
  }

  const stripeSecret = process.env.STRIPE_SECRET_KEY;
  if (!stripeSecret) {
    throw new HttpsError(
      "failed-precondition",
      "STRIPE_SECRET_KEY is missing. Configure Firebase Functions env first.",
    );
  }

  const payload = (request.data ?? {}) as DemoPaymentPayload;
  const draft = payload.draft ?? {};

  const salonId = (draft.salonId ?? "").trim();
  const salonName = (draft.salonName ?? "Salon").trim();
  const bookingDateIso = (draft.bookingDateIso ?? "").trim();
  const bookingTime = (draft.bookingTime ?? "").trim();
  const stylistLabel = (draft.stylistLabel ?? "-").trim();
  const paymentMethodType = (payload.paymentMethodType ?? "card").trim();
  const discountAmount = safeToNumber(draft.discountAmount);
  const totalAmount = safeToNumber(draft.totalAmount);

  if (salonId.length === 0) {
    throw new HttpsError("invalid-argument", "draft.salonId is required.");
  }
  if (bookingDateIso.length === 0 || bookingTime.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "draft.bookingDateIso and draft.bookingTime are required.",
    );
  }

  const draftServices = Array.isArray(draft.services) ? draft.services : [];
  if (draftServices.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "At least one service is required to process payment.",
    );
  }

  const services = draftServices.map((service) => ({
    name: (service.name ?? "Service").toString(),
    price: safeToNumber(service.price),
  }));

  const amountCents = Math.max(50, Math.round(totalAmount * 100));
  const stripe = new Stripe(stripeSecret, {apiVersion: "2024-06-20"});
  const testPaymentMethod = resolveStripeTestPaymentMethod(
    paymentMethodType,
    payload.selectedCard?.brand,
  );

  let paymentIntent: Stripe.PaymentIntent;
  try {
    paymentIntent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: "usd",
      confirm: true,
      payment_method: testPaymentMethod,
      automatic_payment_methods: {enabled: false},
      payment_method_types: ["card"],
      description: "Salon demo payment",
      metadata: {
        mode: "demo",
        uid,
        salonId,
        paymentMethodType,
      },
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Stripe payment failed.";
    throw new HttpsError("internal", message);
  }

  const firestore = getFirestore();
  const bookingRef = firestore.collection("bookings").doc();

  const userDoc = await firestore.collection("users").doc(uid).get();
  const userData = userDoc.data() ?? {};

  let authUserEmail = "";
  try {
    const authUser = await getAuth().getUser(uid);
    authUserEmail = (authUser.email ?? "").trim();
  } catch {
    authUserEmail = "";
  }

  const customerName = (
    userData["displayName"] ??
    userData["name"] ??
    userData["fullName"] ??
    "Guest User"
  )
    .toString()
    .trim();
  const customerPhone = (
    userData["phone"] ?? userData["phoneNumber"] ?? userData["mobile"] ?? "-"
  )
    .toString()
    .trim();
  const customerEmail = (
    authUserEmail || (userData["email"] ?? "").toString().trim()
  ).trim();

  const paymentMethodLabel = paymentLabel(paymentMethodType);
  const bookingDate = new Date(bookingDateIso);

  const receipt = {
    salon: {
      id: salonId,
      name: salonName,
    },
    booking: {
      dateIso: bookingDate.toISOString(),
      time: bookingTime,
      stylist: stylistLabel,
      paymentMode: "pay_online_demo",
    },
    services,
    pricing: {
      discount: discountAmount,
      total: totalAmount,
    },
    customer: {
      uid,
      name: customerName,
      phone: customerPhone,
      email: customerEmail,
    },
  };

  await bookingRef.set({
    bookingId: bookingRef.id,
    salonId,
    paymentMode: "pay_online_demo",
    paymentStatus:
      paymentIntent.status === "succeeded" ? "paid_demo" : "pending_demo",
    createdAt: FieldValue.serverTimestamp(),
    stripe: {
      paymentIntentId: paymentIntent.id,
      status: paymentIntent.status,
      amount: amountCents,
      currency: "usd",
      testMode: true,
    },
    receipt,
  });

  const qrPayloadJson = JSON.stringify({
    bookingId: bookingRef.id,
    salonId,
    paymentMode: "pay_online_demo",
    paymentStatus: paymentIntent.status,
    paymentIntentId: paymentIntent.id,
    createdAtEpoch: Date.now(),
  });

  return {
    success: true,
    bookingId: bookingRef.id,
    customerName,
    customerPhone,
    paymentModeLabel: paymentMethodLabel,
    qrPayloadJson,
  };
});

/**
 * Validates email format.
 * @param {string} email Email address.
 * @return {void}
 */
function validateEmail(email: string): void {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    throw new HttpsError("invalid-argument", "Invalid email format.");
  }
}

/**
 * Validates a six-digit OTP code.
 * @param {string} code Six-digit OTP.
 * @return {void}
 */
function validateOtp(code: string): void {
  if (!/^\d{6}$/.test(code)) {
    throw new HttpsError(
      "invalid-argument",
      "sixDigitCode must be exactly 6 numeric digits.",
    );
  }
}

/**
 * Builds OTP email HTML.
 * @param {string} code Six-digit OTP.
 * @return {string}
 */
function buildOtpHtml(code: string): string {
  return [
    "<div style=\"font-family:Arial,sans-serif;" +
      "background:#f4f7ff;padding:24px;\">",
    "<div style=\"max-width:560px;margin:0 auto;background:#ffffff;",
    "border-radius:12px;padding:28px;\">",
    "<h2 style=\"margin:0 0 12px;color:#0B0C15;\">Your Salon App OTP</h2>",
    "<p style=\"margin:0 0 16px;color:#333333;line-height:1.6;\">",
    "Use the following 6-digit verification code to continue signing in.",
    "</p>",
    "<div style=\"margin:18px 0;padding:14px 18px;background:#F6F8FF;",
    "border:1px solid #235AFF;border-radius:10px;display:inline-block;\">",
    "<span style=\"font-size:28px;letter-spacing:8px;font-weight:700;",
    `color:#235AFF;">${code}</span>`,
    "</div>",
    "<p style=\"margin:10px 0 0;color:#939393;" +
      "font-size:13px;line-height:1.5;\">",
    "This code expires shortly. If you did not request this code, ignore this",
    "email.</p>",
    "</div>",
    "</div>",
  ].join("");
}

/**
 * Coerces an unknown value to a safe number.
 * @param {unknown} value Unknown numeric value.
 * @return {number}
 */
function safeToNumber(value: unknown): number {
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : 0;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

/**
 * Maps selected method to Stripe test payment method token.
 * @param {string} paymentMethodType Selected method type.
 * @param {string=} cardBrand Optional saved-card brand.
 * @return {string}
 */
function resolveStripeTestPaymentMethod(
  paymentMethodType: string,
  cardBrand?: string,
): string {
  const normalizedType = paymentMethodType.toLowerCase();
  if (normalizedType === "applePay" || normalizedType === "googlePay") {
    return "pm_card_visa";
  }

  const brand = (cardBrand ?? "").toLowerCase();
  if (brand.includes("master")) {
    return "pm_card_mastercard";
  }
  if (brand.includes("amex")) {
    return "pm_card_amex";
  }
  return "pm_card_visa";
}

/**
 * Creates a readable payment label for receipts.
 * @param {string} paymentMethodType Selected payment method type.
 * @return {string}
 */
function paymentLabel(paymentMethodType: string): string {
  const normalizedType = paymentMethodType.toLowerCase();
  if (normalizedType === "applepay") {
    return "Apple Pay (Demo)";
  }
  if (normalizedType === "googlepay") {
    return "Google Pay (Demo)";
  }
  return "Card (Demo)";
}
