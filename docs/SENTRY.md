# Sentry

SweKitty now has mobile telemetry hooks for handled connection and session failures.

## Secrets

Add these repository secrets before expecting remote events:

- `SENTRY_DSN_IOS`
- `SENTRY_DSN_ANDROID`

Optional later, for symbol and source uploads:

- `SENTRY_AUTH_TOKEN`
- `SENTRY_ORG`
- `SENTRY_PROJECT_IOS`
- `SENTRY_PROJECT_ANDROID`

## Current behavior

- iOS reads `SentryDSN` from the app bundle at build time.
- Android reads `BuildConfig.SENTRY_DSN` at build time.
- If the DSN is empty, telemetry is a no-op.
- If the DSN is present, handled errors from:
  - harness connect
  - session creation
  - agent switching
  are captured with endpoint, assistant, and session context.

## Why this exists

The harness bearer token is minted in memory on every server startup. A saved mobile pairing can therefore become stale after a harness restart. Before this patch, the apps showed `Ready` immediately after `connect()` even though no authenticated round-trip had happened yet.

The current UI now treats that state as `Paired`, not verified, and maps auth failures to a re-pair instruction instead of a raw `Auth(message: "auth")` banner.

## Next step

Once Sentry projects exist, add the DSNs as repo secrets and cut a new build. That is enough to start receiving these handled mobile errors remotely.
