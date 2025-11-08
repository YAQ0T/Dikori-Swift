// server/utils/humanVerification.js
const { verifyRecaptchaToken } = require("./recaptcha");
const { verifyPrivateAccessToken } = require("./privateAccessToken");

const DEFAULT_RECAPTCHA_ACTION = "general";
const ENV_MIN_SCORE = Number(process.env.RECAPTCHA_MIN_SCORE);
const DEFAULT_RECAPTCHA_MIN_SCORE = Number.isFinite(ENV_MIN_SCORE)
  ? ENV_MIN_SCORE
  : 0.5;

function isNonEmpty(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function getLogger(req) {
  if (req?.app?.locals?.logger) {
    return req.app.locals.logger;
  }
  return console;
}

function recordMetric(req, path) {
  const metrics = req?.app?.locals?.metrics;
  if (metrics && typeof metrics.increment === "function") {
    metrics.increment(path);
  }
}

function logWith(logger, level, message, meta) {
  if (!logger) {
    return;
  }
  const payload = meta ? [message, meta] : [message];
  if (typeof logger[level] === "function") {
    logger[level](...payload);
  } else if (typeof logger.log === "function") {
    logger.log(...payload);
  }
}

async function ensureHumanVerification(
  req,
  res,
  {
    recaptchaAction = DEFAULT_RECAPTCHA_ACTION,
    recaptchaMinScore = DEFAULT_RECAPTCHA_MIN_SCORE,
    required = true,
  } = {}
) {
  const logger = getLogger(req);

  const bypass =
    process.env.NODE_ENV === "test" ||
    process.env.HUMAN_VERIFICATION_BYPASS === "1" ||
    process.env.RECAPTCHA_TEST_BYPASS === "1";

  if (bypass) {
    logWith(logger, "info", "Human verification bypassed", {
      method: "bypass",
      path: req?.originalUrl,
    });
    recordMetric(req, "human_verification.bypass");
    return true;
  }

  const patTokenHeader = req?.get?.("Private-Token");
  const patTokenBody = req?.body?.privateAccessToken || req?.body?.privateToken;
  const patToken = isNonEmpty(patTokenHeader)
    ? patTokenHeader.trim()
    : isNonEmpty(patTokenBody)
    ? patTokenBody.trim()
    : null;

  if (patToken) {
    const patResult = await verifyPrivateAccessToken({
      token: patToken,
      remoteIp: req?.ip,
      userAgent: req?.get?.("user-agent"),
      logger,
    });

    if (patResult.success) {
      logWith(logger, "info", "Human verification succeeded", {
        method: "pat",
        path: req?.originalUrl,
      });
      recordMetric(req, "human_verification.pat.success");
      return true;
    }

    if (patResult.code !== "PAT_NOT_CONFIGURED") {
      logWith(logger, "warn", "Human verification failed via PAT", {
        method: "pat",
        statusCode: patResult.statusCode,
        code: patResult.code,
        path: req?.originalUrl,
      });
      recordMetric(req, "human_verification.pat.failure");

      const status = patResult.statusCode || 400;
      if (status >= 500) {
        logWith(logger, "error", "PAT verification error", {
          method: "pat",
          statusCode: status,
          code: patResult.code,
        });
      }

      res.status(status).json({
        message: "فشل التحقق البشري (Private Access Token)",
        error: patResult.code || "PAT_VERIFICATION_FAILED",
        ...(patResult.details ? { details: patResult.details } : {}),
      });
      return false;
    }
    logWith(logger, "warn", "PAT verification skipped - not configured", {
      method: "pat",
      path: req?.originalUrl,
    });
    recordMetric(req, "human_verification.pat.unavailable");
    // If PAT isn't configured, fall back to reCAPTCHA
  }

  const recaptchaToken = isNonEmpty(req?.body?.recaptchaToken)
    ? req.body.recaptchaToken.trim()
    : null;

  if (!recaptchaToken) {
    if (!required) {
      logWith(logger, "info", "Human verification skipped (optional)", {
        method: "none",
        path: req?.originalUrl,
      });
      recordMetric(req, "human_verification.optional.skip");
      return true;
    }

    logWith(logger, "warn", "Missing human verification token", {
      method: "recaptcha",
      path: req?.originalUrl,
    });
    recordMetric(req, "human_verification.recaptcha.missing");

    res.status(400).json({
      message: "رمز التحقق البشري مطلوب",
      error: "MISSING_HUMAN_TOKEN",
    });
    return false;
  }

  try {
    await verifyRecaptchaToken({
      token: recaptchaToken,
      expectedAction: recaptchaAction,
      minScore: recaptchaMinScore,
    });

    logWith(logger, "info", "Human verification succeeded", {
      method: "recaptcha",
      path: req?.originalUrl,
      action: recaptchaAction,
    });
    recordMetric(req, "human_verification.recaptcha.success");
    return true;
  } catch (err) {
    const status = err?.statusCode || 400;
    const code = err?.code || "RECAPTCHA_FAILED";

    if (status >= 500) {
      logWith(logger, "error", "reCAPTCHA verification error", {
        method: "recaptcha",
        statusCode: status,
        code,
        path: req?.originalUrl,
      });
    } else {
      logWith(logger, "warn", "Human verification failed via reCAPTCHA", {
        method: "recaptcha",
        statusCode: status,
        code,
        path: req?.originalUrl,
      });
    }
    recordMetric(req, "human_verification.recaptcha.failure");

    res.status(status).json({
      message: "فشل التحقق البشري (reCAPTCHA)",
      error: code,
      ...(err?.details ? { details: err.details } : {}),
    });
    return false;
  }
}

module.exports = {
  ensureHumanVerification,
  DEFAULT_RECAPTCHA_MIN_SCORE,
};
