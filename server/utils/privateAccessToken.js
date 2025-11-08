// server/utils/privateAccessToken.js
const axios = require("axios");

const DEFAULT_TIMEOUT = 5000;
const DEFAULT_ENDPOINT =
  "https://token.relay.apple.com/v1/private-access-token/verify";

function getLogger(source) {
  if (!source) {
    return console;
  }
  if (typeof source.info === "function") {
    return source;
  }
  if (source.logger) {
    return getLogger(source.logger);
  }
  return console;
}

function resolvePatConfig() {
  const url = process.env.PAT_VERIFICATION_URL || DEFAULT_ENDPOINT;
  const issuer = process.env.PAT_ISSUER_ID || process.env.PAT_ISSUER;
  const keyId = process.env.PAT_KEY_ID || process.env.PAT_KEYID;
  const teamId = process.env.PAT_TEAM_ID;
  const origin = process.env.PAT_ORIGIN || process.env.APP_ORIGIN;
  const timeoutEnv = Number(process.env.PAT_HTTP_TIMEOUT_MS);
  const timeout = Number.isFinite(timeoutEnv) && timeoutEnv > 0
    ? timeoutEnv
    : DEFAULT_TIMEOUT;

  return {
    url,
    issuer,
    keyId,
    teamId,
    origin,
    timeout,
  };
}

function isPrivateAccessTokenConfigured() {
  const cfg = resolvePatConfig();
  return Boolean(cfg.issuer && cfg.keyId);
}

async function verifyPrivateAccessToken({
  token,
  remoteIp,
  userAgent,
  logger: loggerLike,
} = {}) {
  const logger = getLogger(loggerLike);

  if (!token || typeof token !== "string" || token.trim().length === 0) {
    return {
      success: false,
      statusCode: 400,
      code: "PAT_TOKEN_MISSING",
      message: "Private Access Token value is required",
    };
  }

  const cfg = resolvePatConfig();
  if (!cfg.issuer || !cfg.keyId) {
    return {
      success: false,
      statusCode: 503,
      code: "PAT_NOT_CONFIGURED",
      message: "Private Access Token verification is not configured",
    };
  }

  const body = {
    token: token.trim(),
    issuer: cfg.issuer,
    keyId: cfg.keyId,
  };

  if (cfg.teamId) {
    body.teamId = cfg.teamId;
  }
  if (cfg.origin) {
    body.origin = cfg.origin;
  }
  if (remoteIp) {
    body.clientIp = remoteIp;
  }

  const headers = { "Content-Type": "application/json" };
  if (userAgent) {
    headers["User-Agent"] = userAgent;
  }

  try {
    const { data, status } = await axios.post(cfg.url, body, {
      headers,
      timeout: cfg.timeout,
    });

    const tokenAccepted = Boolean(
      data?.isValid ?? data?.valid ?? data?.success ?? data?.status === "ok"
    );

    if (!tokenAccepted) {
      return {
        success: false,
        statusCode: 400,
        code: "PAT_REJECTED",
        message: "Apple rejected the Private Access Token",
        details: data || null,
      };
    }

    logger.info?.("Private Access Token verified successfully", {
      method: "pat",
      status,
    });

    return {
      success: true,
      statusCode: status,
      data: data || {},
    };
  } catch (err) {
    if (err?.response) {
      return {
        success: false,
        statusCode: err.response.status || 400,
        code: "PAT_HTTP_ERROR",
        message: "Apple Private Access Token verification failed",
        details: err.response.data || null,
      };
    }

    if (err?.code === "ECONNABORTED") {
      return {
        success: false,
        statusCode: 504,
        code: "PAT_TIMEOUT",
        message: "Apple Private Access Token verification timed out",
      };
    }

    return {
      success: false,
      statusCode: 502,
      code: "PAT_REQUEST_FAILED",
      message: "Unable to verify Private Access Token",
      details: err?.message ? { message: err.message } : null,
    };
  }
}

module.exports = {
  verifyPrivateAccessToken,
  isPrivateAccessTokenConfigured,
  resolvePatConfig,
};
