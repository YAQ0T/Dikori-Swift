# Server Environment Notes

## Human verification

The API now supports both Google reCAPTCHA tokens and Apple Private Access Tokens (PAT) for human-verification gates (orders checkout, contact form, etc.).

### Required variables

| Variable | Description |
| --- | --- |
| `RECAPTCHA_SECRET` | Google reCAPTCHA secret used when a token is supplied. |
| `PAT_ISSUER_ID` (or `PAT_ISSUER`) | Apple-issued identifier for the PAT issuer. |
| `PAT_KEY_ID` (or `PAT_KEYID`) | Key identifier for the PAT signing key. |

### Optional variables

| Variable | Description |
| --- | --- |
| `PAT_VERIFICATION_URL` | Override for Apple verification endpoint. Defaults to `https://token.relay.apple.com/v1/private-access-token/verify`. |
| `PAT_TEAM_ID` | Optional Apple team identifier, forwarded to the verification endpoint. |
| `PAT_ORIGIN` / `APP_ORIGIN` | Expected origin/hostname to forward with the PAT verification request. |
| `PAT_HTTP_TIMEOUT_MS` | Timeout (ms) for the verification request. Defaults to 5000. |
| `HUMAN_VERIFICATION_BYPASS` | When set to `1`, bypasses human verification (useful locally). Existing `RECAPTCHA_TEST_BYPASS` is also honoured. |
| `CONTACT_REQUIRE_HUMAN_VERIFICATION` | When set to `1`, the contact form requires a PAT or reCAPTCHA token. |

### Client usage

* Send PATs via the standard `Private-Token` header or `privateAccessToken` field in the request body.
* If a PAT is unavailable, send a standard `recaptchaToken` field. The server selects PAT first, then falls back to reCAPTCHA.
* Administrators can distinguish which mechanism passed/failed via the structured logs and metrics emitted under the `human_verification.*` namespace.

## Logging & metrics

* Successful and failed validations log the verification method (`pat`, `recaptcha`, or `bypass`).
* When an application metrics client is exposed via `app.locals.metrics`, counters are incremented at:
  * `human_verification.pat.success`
  * `human_verification.pat.failure`
  * `human_verification.pat.unavailable`
  * `human_verification.recaptcha.success`
  * `human_verification.recaptcha.failure`
  * `human_verification.recaptcha.missing`
  * `human_verification.optional.skip`
  * `human_verification.bypass`

These counters allow dashboards/alerts to track the share of requests validated by PAT versus reCAPTCHA.
