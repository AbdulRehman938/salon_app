import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, HttpsError} from "firebase-functions/v2/https";

setGlobalOptions({maxInstances: 10});

type SendOtpPayload = {
	email?: string;
	sixDigitCode?: string;
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

	finalEmailValidation(email);
	finalOtpValidation(sixDigitCode);

	const brevoApiKey = process.env.BREVO_API_KEY;
	if (!brevoApiKey) {
		throw new HttpsError(
			"failed-precondition",
			"BREVO_API_KEY is not configured in environment variables.",
		);
	}

	const subject = "Your Salon App OTP";
	const htmlContent = buildOtpHtml(sixDigitCode);

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
			subject,
			htmlContent,
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

	return {
		success: true,
		message: "OTP email sent successfully.",
	};
});

function finalEmailValidation(email: string): void {
	const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
	if (!emailRegex.test(email)) {
		throw new HttpsError("invalid-argument", "Invalid email format.");
	}
}

function finalOtpValidation(code: string): void {
	if (!/^\d{6}$/.test(code)) {
		throw new HttpsError(
			"invalid-argument",
			"sixDigitCode must be exactly 6 numeric digits.",
		);
	}
}

function buildOtpHtml(code: string): string {
	return `
		<div style="font-family:Arial,sans-serif;background:#f4f7ff;padding:24px;">
			<div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:12px;padding:28px;">
				<h2 style="margin:0 0 12px;color:#0B0C15;">Your Salon App OTP</h2>
				<p style="margin:0 0 16px;color:#333333;line-height:1.6;">
					Use the following 6-digit verification code to continue signing in.
				</p>
				<div style="margin:18px 0;padding:14px 18px;background:#F6F8FF;border:1px solid #235AFF;border-radius:10px;display:inline-block;">
					<span style="font-size:28px;letter-spacing:8px;font-weight:700;color:#235AFF;">${code}</span>
				</div>
				<p style="margin:10px 0 0;color:#939393;font-size:13px;line-height:1.5;">
					This code expires shortly. If you did not request this code, you can ignore this email.
				</p>
			</div>
		</div>
	`;
}
