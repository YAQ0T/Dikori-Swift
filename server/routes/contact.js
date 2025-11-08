const express = require("express");
const router = express.Router();
const nodemailer = require("nodemailer");

const { ensureHumanVerification } = require("../utils/humanVerification");

const CONTACT_VERIFICATION_REQUIRED =
  process.env.CONTACT_REQUIRE_HUMAN_VERIFICATION === "1";

/**
 * POST /api/contact
 * Body: { name, email, message, recaptchaToken?, privateAccessToken? }
 */
router.post("/", async (req, res) => {
  const { name, email, message } = req.body || {};

  if (!name || !email || !message) {
    return res.status(400).json({ error: "جميع الحقول مطلوبة" });
  }
  if (
    String(name).length > 200 ||
    String(email).length > 320 ||
    String(message).length > 5000
  ) {
    return res.status(400).json({ error: "المدخلات أطول من المسموح" });
  }

  try {
    const verificationPassed = await ensureHumanVerification(req, res, {
      recaptchaAction: "contact",
      required: CONTACT_VERIFICATION_REQUIRED,
    });
    if (!verificationPassed) {
      return;
    }

    // Create transporter from environment (never hardcode secrets)
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || "smtp.gmail.com",
      port: Number(process.env.SMTP_PORT || 587),
      secure: false,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });

    const fromAddr = process.env.CONTACT_FROM || "no-reply@yourdomain.com";
    const toAddr = process.env.CONTACT_TO || process.env.SMTP_USER;

    await transporter.sendMail({
      from: `"Madina Contact" <${fromAddr}>`,
      to: toAddr,
      replyTo: email, // set reply-to to the user
      subject: "رسالة من نموذج التواصل",
      html: `
        <h2>رسالة جديدة من نموذج التواصل</h2>
        <h3>الاسم:</h3><p>${String(name).trim()}</p>
        <h3>البريد الإلكتروني:</h3><p>${String(email).trim()}</p>
        <h3>الرسالة:</h3><p>${String(message).trim()}</p>
      `,
    });

    res.status(200).json({ message: "✅ تم إرسال الرسالة بنجاح" });
  } catch (err) {
    console.error("❌ فشل في إرسال البريد:", err?.message || err);
    res.status(500).json({ error: "فشل في إرسال الرسالة" });
  }
});

module.exports = router;
