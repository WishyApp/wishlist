// Revokes the Sign in with Apple tokens of an account being deleted, as the
// App Store requires (guideline 5.1.1(v)).
//
// The app sends a fresh authorization code from the Apple sheet: it is
// exchanged here for a refresh token, which is then revoked. No Apple token
// is ever stored.

const APPLE_AUTH_URL = "https://appleid.apple.com/auth";

// The revocation runs before the deletion: Apple hanging must not make the
// whole function time out.
const APPLE_TIMEOUT_MS = 5000;

export interface AppleConfig {
  teamId: string;
  keyId: string;
  /** Content of the .p8 key, PEM (PKCS#8). */
  privateKey: string;
  /** The bundle ID: the audience of the app's Apple tokens. */
  clientId: string;
}

export class AppleRevocationError extends Error {}

/** The authorization code the app sent, if any. */
export function authorizationCodeOf(body: unknown): string | null {
  if (typeof body !== "object" || body === null) return null;
  const code = (body as Record<string, unknown>).appleAuthorizationCode;
  return typeof code === "string" && code.length > 0 ? code : null;
}

/** The Apple user ID (`sub`) of the account, null when it has no Apple identity. */
export function appleUserIdOf(
  identities: { provider: string; id?: string; identity_data?: Record<string, unknown> }[] | undefined,
): string | null {
  const identity = identities?.find((i) => i.provider === "apple");
  const sub = identity?.identity_data?.sub;
  if (typeof sub === "string" && sub.length > 0) return sub;
  return identity?.id ?? null;
}

/** Null when a secret is missing: the revocation is then skipped. */
export function appleConfigFromEnv(
  get: (name: string) => string | undefined,
): AppleConfig | null {
  const teamId = get("APPLE_TEAM_ID")?.trim();
  const keyId = get("APPLE_KEY_ID")?.trim();
  // Secrets set from a shell often carry literal "\n" instead of newlines.
  const privateKey = get("APPLE_PRIVATE_KEY")?.replaceAll("\\n", "\n").trim();
  const clientId = get("APPLE_CLIENT_ID")?.trim();
  if (!teamId || !keyId || !privateKey || !clientId) {
    return null;
  }
  return { teamId, keyId, privateKey, clientId };
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function base64UrlDecode(text: string): Uint8Array {
  const base64 = text.replaceAll("-", "+").replaceAll("_", "/");
  const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
}

function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

/**
 * The client secret Apple expects: a JWT signed with the .p8 key (ES256).
 * Web Crypto already returns the raw r || s signature JWS needs.
 */
export async function createClientSecret(
  config: AppleConfig,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string> {
  const encoder = new TextEncoder();
  const header = { alg: "ES256", kid: config.keyId };
  const payload = {
    iss: config.teamId,
    iat: nowSeconds,
    // Only used for the two calls below.
    exp: nowSeconds + 5 * 60,
    aud: "https://appleid.apple.com",
    sub: config.clientId,
  };
  const signingInput = `${base64UrlEncode(encoder.encode(JSON.stringify(header)))}.${
    base64UrlEncode(encoder.encode(JSON.stringify(payload)))
  }`;
  const key = await importPrivateKey(config.privateKey);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput),
  );
  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
}

/** The `sub` claim of an ID token, read without checking its signature. */
function subjectOf(idToken: string): string | undefined {
  try {
    const payload = JSON.parse(
      new TextDecoder().decode(base64UrlDecode(idToken.split(".")[1])),
    );
    return typeof payload.sub === "string" ? payload.sub : undefined;
  } catch {
    return undefined;
  }
}

async function postForm(
  fetchFn: typeof fetch,
  path: string,
  form: Record<string, string>,
): Promise<Response> {
  return await fetchFn(`${APPLE_AUTH_URL}/${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(form),
    signal: AbortSignal.timeout(APPLE_TIMEOUT_MS),
  });
}

/**
 * Exchanges [authorizationCode] and revokes the resulting token.
 *
 * Returns whether the code was issued to [appleUserId], the Apple ID of the
 * account being deleted. A code from another Apple ID (a family device signed
 * in with someone else's Apple ID) is revoked all the same: the exchange
 * created that authorization, and the code can only come from the caller's
 * own device. The deleted account's authorization is then left as is.
 */
export async function revokeAppleTokens({
  config,
  authorizationCode,
  appleUserId,
  fetchFn = fetch,
}: {
  config: AppleConfig;
  authorizationCode: string;
  appleUserId: string;
  fetchFn?: typeof fetch;
}): Promise<{ belongsToAccount: boolean }> {
  const clientSecret = await createClientSecret(config);

  const tokenResponse = await postForm(fetchFn, "token", {
    client_id: config.clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: "authorization_code",
  });
  if (!tokenResponse.ok) {
    throw new AppleRevocationError(
      `Apple token exchange failed: ${tokenResponse.status} ${await tokenResponse.text()}`,
    );
  }
  const tokens = await tokenResponse.json();
  const belongsToAccount = typeof tokens.id_token === "string" &&
    subjectOf(tokens.id_token) === appleUserId;

  const refreshToken = typeof tokens.refresh_token === "string" ? tokens.refresh_token : null;
  const token = refreshToken ?? tokens.access_token;
  if (typeof token !== "string") {
    throw new AppleRevocationError("Apple returned no token to revoke");
  }

  const revokeResponse = await postForm(fetchFn, "revoke", {
    client_id: config.clientId,
    client_secret: clientSecret,
    token,
    token_type_hint: refreshToken ? "refresh_token" : "access_token",
  });
  if (!revokeResponse.ok) {
    throw new AppleRevocationError(
      `Apple revocation failed: ${revokeResponse.status} ${await revokeResponse.text()}`,
    );
  }
  return { belongsToAccount };
}
