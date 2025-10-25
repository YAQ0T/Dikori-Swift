/* ===========================
 *  madina-ecommerce — server/index.js
 *  Express + MongoDB + Lahza Webhooks (CJS)
 * =========================== */

const express = require("express");
const cors = require("cors");
const mongoose = require("mongoose");
const crypto = require("crypto");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3001;

const normalizeOrigin = (value = "") => {
  if (!value) return "";
  try {
    return new URL(value).origin;
  } catch {
    return value.trim().replace(/\/$/, "");
  }
};

const parseOriginList = (value = "") =>
  String(value)
    .split(",")
    .map((origin) => normalizeOrigin(origin.trim()))
    .filter(Boolean);

const ENV_CLIENT_ORIGINS = parseOriginList(process.env.CLIENT_ORIGINS);
const DEFAULT_DEV_ORIGIN_MATCHERS = [
  /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i,
];

const isOriginAllowed = (origin) => {
  if (!origin) return true; // Allow non-CORS/SSR requests.
  const normalizedOrigin = normalizeOrigin(origin);
  if (ENV_CLIENT_ORIGINS.length) {
    return ENV_CLIENT_ORIGINS.some((allowed) => allowed === normalizedOrigin);
  }
  return DEFAULT_DEV_ORIGIN_MATCHERS.some((regex) => regex.test(normalizedOrigin));
};

const corsBaseOptions = {
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: [
    "Content-Type",
    "Authorization",
    "x-forwarded-for",
    "x-lahza-signature",
  ],
};

/* ---------- CORS ---------- */
app.use(
  cors((req, cb) => {
    const origin = req.headers.origin;
    const allowed = isOriginAllowed(origin);

    cb(null, {
      ...corsBaseOptions,
      origin: origin ? (allowed ? origin : false) : true,
      credentials: allowed,
    });
  })
);

/* ---------- Trust Proxy (قبل استخدام IP) ---------- */
app.set("trust proxy", 1);

/* =====================================================
 *  WEBHOOK: Lahza  (ضروري يكون قبل express.json)
 *  - يستقبل RAW JSON
 *  - يتحقق من x-lahza-signature (HMAC-SHA256 على الـ raw body)
 *  - عند charge.success: يخصم مخزون أصناف الطلب، ويعلّم الطلب مدفوع
 *  - يرجع 200 بسرعة لتجنّب إعادة المحاولات الطويلة
 * ===================================================== */

const LAHZA_SECRET_KEY = process.env.LAHZA_SECRET_KEY || "";
const WEBHOOK_IP_WHITELIST =
  String(process.env.WEBHOOK_IP_WHITELIST || "true") === "true";

function stripIpv4Port(candidate = "") {
  const match = String(candidate)
    .trim()
    .match(/^(\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?$/);
  return match ? match[1] : "";
}

function normalizeIp(value = "") {
  if (!value) return "";
  const collapsed = String(value).trim().replace(/\s+/g, " ");
  if (!collapsed) return "";
  const mappedMatch = collapsed.match(/^::ffff:\s*(.+)$/i);
  if (mappedMatch) {
    const candidate = stripIpv4Port(mappedMatch[1]);
    if (candidate) {
      return candidate;
    }
  }
  const ipv4 = stripIpv4Port(collapsed);
  if (ipv4) {
    return ipv4;
  }
  return collapsed;
}

const WEBHOOK_ALLOWED_IPS = (
  process.env.WEBHOOK_ALLOWED_IPS || "161.35.20.140,165.227.134.20"
)
  .split(",")
  .map((s) => normalizeIp(s))
  .filter(Boolean);

// ⚠️ موديلات مستخدمة داخل الـ webhook
const Order = require("./models/Order");
const Variant = require("./models/Variant");
const Product = require("./models/Product");
const {
  prepareLahzaPaymentUpdate,
  verifyLahzaTransaction,
} = require("./utils/lahza");
const { queueOrderSummarySMS } = require("./utils/orderSms");

function getClientIp(req) {
  const xff = req.headers["x-forwarded-for"];
  if (xff) {
    const first = xff.split(",")[0];
    return normalizeIp(first);
  }
  if (req.socket?.remoteAddress) {
    return normalizeIp(req.socket.remoteAddress);
  }
  if (req.ip) {
    return normalizeIp(req.ip);
  }
  return "";
}

async function decrementStockByOrderItems(items = []) {
  await Promise.all(
    (items || []).map((ci) =>
      Variant.updateOne(
        { _id: ci.variantId, "stock.inStock": { $gte: ci.quantity } },
        { $inc: { "stock.inStock": -ci.quantity } }
      )
    )
  );
}

async function lahzaWebhookHandler(req, res) {
  try {
    if (!LAHZA_SECRET_KEY) {
      console.error("⚠️ LAHZA_SECRET_KEY غير معرّف في .env");
      return res.sendStatus(200);
    }

    if (WEBHOOK_IP_WHITELIST && WEBHOOK_ALLOWED_IPS.length) {
      const ip = getClientIp(req);
      const pass = WEBHOOK_ALLOWED_IPS.some((allowed) => ip === allowed);
      if (!pass) {
        console.warn("🚫 Webhook مرفوض من IP غير مسموح:", ip);
        return res.sendStatus(200);
      }
    }

    const signature = req.get("x-lahza-signature") || "";
    let computed;
    try {
      computed = crypto
        .createHmac("sha256", LAHZA_SECRET_KEY)
        .update(req.body)
        .digest("hex");
    } catch (e) {
      console.error("❌ فشل إنشاء HMAC:", e.message);
      return res.sendStatus(200);
    }

    let verified = false;
    try {
      verified = crypto.timingSafeEqual(
        Buffer.from(computed, "hex"),
        Buffer.from(signature, "hex")
      );
    } catch {
      verified = false;
    }

    if (!verified) {
      console.warn("⚠️ توقيع Webhook غير صالح");
      return res.sendStatus(200);
    }

    let event;
    try {
      event = JSON.parse(req.body.toString("utf8"));
    } catch (e) {
      console.error("❌ جسم Webhook ليس JSON صالح");
      return res.sendStatus(200);
    }

    // إذا كان حدث نجاح الدفع
    if (event?.event === "charge.success") {
      const rawReference =
        event?.data?.reference !== undefined && event?.data?.reference !== null
          ? event.data.reference
          : event?.data?.ref;

      if (rawReference === undefined || rawReference === null) {
        console.warn("⚠️ Webhook: charge.success بدون مرجع");
        return res.sendStatus(200);
      }

      const reference = String(rawReference).trim();
      if (!reference) {
        console.warn("⚠️ Webhook: charge.success بمرجع فارغ");
        return res.sendStatus(200);
      }

      const order = await Order.findOne({ reference }).lean();
      if (!order) {
        console.warn("⚠️ Webhook: لم يتم العثور على طلب للمرجع", reference);
        return res.sendStatus(200);
      }

      const eventPayload = event.data || {};

      let verification;
      try {
        verification = await verifyLahzaTransaction(reference);
        if (verification.status !== "success") {
          return res.sendStatus(200);
        }
      } catch (e) {
        console.warn("⚠️ فشل التحقق من Lahza:", e?.message || e);
        return res.sendStatus(200);
      }

      const {
        amountMatches,
        currencyMatches,
        amountMinor,
        expectedMinor,
        amountDelta,
        toleranceMinor,
        verifiedCurrency,
        expectedCurrency,
        amountForStorage,
        transactionId,
        cardDetails,
        successSet,
        mismatchSet,
      } = prepareLahzaPaymentUpdate({
        order,
        verification,
        eventPayload,
      });

      if (!amountMatches || !currencyMatches) {
        console.error("🚫 Webhook: تعارض في مبلغ أو عملة الدفع", {
          reference,
          amountMinor,
          expectedMinor,
          amountDelta,
          toleranceMinor,
          verifiedCurrency,
          expectedCurrency,
        });

        if (Object.keys(mismatchSet).length) {
          await Order.updateOne({ _id: order._id }, { $set: mismatchSet });
        }
        return res.sendStatus(200);
      }

      const updated = await Order.findOneAndUpdate(
        { _id: order._id, paymentStatus: { $ne: "paid" } },
        { $set: successSet },
        { new: true }
      ).lean();

      if (!updated) {
        await Order.updateOne({ _id: order._id }, { $set: successSet });
      }

      if (updated) {
        await decrementStockByOrderItems(updated.items || []);
        queueOrderSummarySMS({
          order: updated,
          cardType: cardDetails?.cardType,
          cardLast4: cardDetails?.last4,
        });
      }
    }

    return res.sendStatus(200);
  } catch (e) {
    console.error("🔥 Webhook handler error:", e);
    return res.sendStatus(200);
  }
}

app.post(
  "/api/webhooks/lahza",
  express.raw({ type: "application/json" }),
  lahzaWebhookHandler
);

/* ---------- JSON parsers بعد الـ webhook ---------- */
app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: true }));

/* ---------- Mongo ---------- */

if (process.env.NODE_ENV !== "test") {
  mongoose
    .connect(process.env.MONGO_URI, {
      serverSelectionTimeoutMS: 15000,
      family: 4,
    })
    .then(async () => {
      console.log("✅ MongoDB connected");

      try {
        const dropped = await Product.syncIndexes();
        if (Array.isArray(dropped) && dropped.length) {
          console.log(
            "🔁 Product indexes synchronized (dropped):",
            dropped.join(", ")
          );
        } else {
          console.log("🔁 Product indexes synchronized");
        }
      } catch (err) {
        console.error("⚠️ Failed to sync Product indexes:", err?.message || err);
      }
    })
    .catch((err) => {
      console.error("❌ Mongo error:", err);
      process.exit(1);
    });
}

/* ---------- Routes ---------- */
app.use("/api/contact", require("./routes/contact"));
app.use("/api/auth", require("./routes/auth"));
app.use("/api/variants", require("./routes/variants"));
app.use("/api/products", require("./routes/products"));
app.use("/api/orders", require("./routes/orders"));
app.use("/api/users", require("./routes/user"));
app.use("/api/notifications", require("./routes/notifications"));
app.use("/api/discount-rules", require("./routes/discountRules"));
app.use("/api/discounts", require("./routes/discounts"));
app.use("/api/home-collections", require("./routes/homeCollections"));
app.use("/api/recaptcha", require("./routes/recaptcha"));
app.use("/api/payments", require("./routes/payments"));
app.use("/api/orders", require("./routes/order-status"));

/* ---------- health ---------- */
app.get("/healthz", (_req, res) => res.json({ ok: true }));

/* ---------- boot ---------- */
let server = null;
if (process.env.NODE_ENV !== "test") {
  server = app.listen(PORT, () => console.log(`🚀 Server on :${PORT}`));

  /* ---------- Graceful Shutdown ---------- */
  const shutdown = () => {
    console.log("🛑 Shutting down...");
    server.close(() => {
      mongoose.connection.close(false, () => {
        console.log("🔌 MongoDB connection closed");
        process.exit(0);
      });
    });
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

module.exports = {
  app,
  getClientIp,
  normalizeIp,
  lahzaWebhookHandler,
  WEBHOOK_ALLOWED_IPS,
};
