import { assertEquals, assertRejects } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  type AppleConfig,
  appleConfigFromEnv,
  AppleRevocationError,
  appleUserIdOf,
  authorizationCodeOf,
  createClientSecret,
  revokeAppleTokens,
} from "./apple_revocation.ts";

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function fromBase64Url(text: string): Uint8Array {
  const base64 = text.replaceAll("-", "+").replaceAll("_", "/");
  const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
}

/** A throwaway P-256 key, as Apple's .p8 file holds one. */
async function testKey(): Promise<{ pem: string; publicKey: CryptoKey }> {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of der) binary += String.fromCharCode(byte);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(binary)}\n-----END PRIVATE KEY-----`;
  return { pem, publicKey: pair.publicKey };
}

async function testConfig(): Promise<{ config: AppleConfig; publicKey: CryptoKey }> {
  const { pem, publicKey } = await testKey();
  return {
    config: { teamId: "TEAM123456", keyId: "KEY1234567", privateKey: pem, clientId: "com.raphtang.wishy" },
    publicKey,
  };
}

function idTokenFor(sub: string): string {
  const encode = (value: unknown) => base64Url(new TextEncoder().encode(JSON.stringify(value)));
  return `${encode({ alg: "RS256" })}.${encode({ sub })}.signature`;
}

/** A fetch that answers Apple's two endpoints and records the forms sent. */
function fakeApple(
  { token = new Response(JSON.stringify({ refresh_token: "refresh", id_token: idTokenFor("apple-user") })), revoke = new Response("") }:
    { token?: Response; revoke?: Response } = {},
) {
  const calls: { url: string; form: URLSearchParams }[] = [];
  const fetchFn = ((url: string | URL, init?: RequestInit) => {
    calls.push({ url: url.toString(), form: new URLSearchParams(init?.body as URLSearchParams) });
    return Promise.resolve(url.toString().endsWith("/token") ? token : revoke);
  }) as typeof fetch;
  return { calls, fetchFn };
}

Deno.test("appleConfigFromEnv : null s'il manque un secret", () => {
  const env: Record<string, string> = {
    APPLE_TEAM_ID: "TEAM",
    APPLE_KEY_ID: "KEY",
    APPLE_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----",
    APPLE_CLIENT_ID: "com.raphtang.wishy",
  };
  const config = appleConfigFromEnv((name) => env[name]);
  assertEquals(config?.privateKey, "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----");

  for (const name of Object.keys(env)) {
    assertEquals(appleConfigFromEnv((n) => (n === name ? "  " : env[n])), null, name);
  }
});

Deno.test("createClientSecret : JWT ES256 signé avec la clé .p8", async () => {
  const { config, publicKey } = await testConfig();

  const jwt = await createClientSecret(config, 1_000_000);
  const [header, payload, signature] = jwt.split(".");

  assertEquals(JSON.parse(new TextDecoder().decode(fromBase64Url(header))), { alg: "ES256", kid: "KEY1234567" });
  assertEquals(JSON.parse(new TextDecoder().decode(fromBase64Url(payload))), {
    iss: "TEAM123456",
    iat: 1_000_000,
    exp: 1_000_300,
    aud: "https://appleid.apple.com",
    sub: "com.raphtang.wishy",
  });
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    publicKey,
    fromBase64Url(signature),
    new TextEncoder().encode(`${header}.${payload}`),
  );
  assertEquals(valid, true);
});

Deno.test("revokeAppleTokens : échange le code puis révoque le refresh token", async () => {
  const { config } = await testConfig();
  const { calls, fetchFn } = fakeApple();

  const result = await revokeAppleTokens({ config, authorizationCode: "code", appleUserId: "apple-user", fetchFn });

  assertEquals(result, { belongsToAccount: true });
  assertEquals(calls.map((c) => c.url), [
    "https://appleid.apple.com/auth/token",
    "https://appleid.apple.com/auth/revoke",
  ]);
  assertEquals(calls[0].form.get("code"), "code");
  assertEquals(calls[0].form.get("grant_type"), "authorization_code");
  assertEquals(calls[0].form.get("client_id"), "com.raphtang.wishy");
  assertEquals(calls[1].form.get("token"), "refresh");
  assertEquals(calls[1].form.get("token_type_hint"), "refresh_token");
});

Deno.test("revokeAppleTokens : révoque l'access token sans refresh token", async () => {
  const { config } = await testConfig();
  const { calls, fetchFn } = fakeApple({
    token: new Response(JSON.stringify({ access_token: "access", id_token: idTokenFor("apple-user") })),
  });

  await revokeAppleTokens({ config, authorizationCode: "code", appleUserId: "apple-user", fetchFn });

  assertEquals(calls[1].form.get("token"), "access");
  assertEquals(calls[1].form.get("token_type_hint"), "access_token");
});

Deno.test("revokeAppleTokens : révoque aussi le code d'un autre identifiant Apple", async () => {
  const { config } = await testConfig();
  const { calls, fetchFn } = fakeApple();

  const result = await revokeAppleTokens({ config, authorizationCode: "code", appleUserId: "someone-else", fetchFn });

  assertEquals(result, { belongsToAccount: false });
  assertEquals(calls.length, 2);
  assertEquals(calls[1].form.get("token"), "refresh");
});

Deno.test("revokeAppleTokens : erreur si Apple refuse l'échange ou la révocation", async () => {
  const { config } = await testConfig();

  await assertRejects(
    () =>
      revokeAppleTokens({
        config,
        authorizationCode: "code",
        appleUserId: "apple-user",
        fetchFn: fakeApple({ token: new Response('{"error":"invalid_grant"}', { status: 400 }) }).fetchFn,
      }),
    AppleRevocationError,
  );
  await assertRejects(
    () =>
      revokeAppleTokens({
        config,
        authorizationCode: "code",
        appleUserId: "apple-user",
        fetchFn: fakeApple({ revoke: new Response("", { status: 400 }) }).fetchFn,
      }),
    AppleRevocationError,
  );
});

Deno.test("authorizationCodeOf : code non vide, sinon null", () => {
  assertEquals(authorizationCodeOf({ appleAuthorizationCode: "code" }), "code");
  for (const body of [{}, null, undefined, "code", { appleAuthorizationCode: 42 }, { appleAuthorizationCode: "" }]) {
    assertEquals(authorizationCodeOf(body), null, JSON.stringify(body));
  }
});

Deno.test("appleUserIdOf : sub de l'identité Apple", () => {
  assertEquals(
    appleUserIdOf([
      { provider: "email", id: "uuid" },
      { provider: "apple", id: "apple-id", identity_data: { sub: "apple-sub" } },
    ]),
    "apple-sub",
  );
  assertEquals(appleUserIdOf([{ provider: "apple", id: "apple-id", identity_data: {} }]), "apple-id");
  assertEquals(appleUserIdOf([{ provider: "google", id: "g" }]), null);
  assertEquals(appleUserIdOf(undefined), null);
});

Deno.test("revokeAppleTokens : id_token absent ou sans sub, révoqué mais hors du compte", async () => {
  const { config } = await testConfig();
  for (const tokens of [{ refresh_token: "r" }, { refresh_token: "r", id_token: "pas-un-jwt" }, { refresh_token: "r", id_token: idTokenFor("") }]) {
    const { calls, fetchFn } = fakeApple({ token: new Response(JSON.stringify(tokens)) });
    const result = await revokeAppleTokens({ config, authorizationCode: "code", appleUserId: "apple-user", fetchFn });
    assertEquals(result, { belongsToAccount: false });
    assertEquals(calls.length, 2);
  }
});

Deno.test("revokeAppleTokens : erreur sans jeton à révoquer", async () => {
  const { config } = await testConfig();
  const { calls, fetchFn } = fakeApple({
    token: new Response(JSON.stringify({ id_token: idTokenFor("apple-user") })),
  });

  await assertRejects(
    () => revokeAppleTokens({ config, authorizationCode: "code", appleUserId: "apple-user", fetchFn }),
    AppleRevocationError,
  );
  assertEquals(calls.length, 1);
});

Deno.test("revokeAppleTokens : une clé invalide rejette sans appeler Apple", async () => {
  const { config } = await testConfig();
  const { calls, fetchFn } = fakeApple();

  await assertRejects(() =>
    revokeAppleTokens({
      config: { ...config, privateKey: "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----" },
      authorizationCode: "code",
      appleUserId: "apple-user",
      fetchFn,
    })
  );
  assertEquals(calls.length, 0);
});

Deno.test("revokeAppleTokens : appels en formulaire avec un délai maximum", async () => {
  const { config } = await testConfig();
  const inits: RequestInit[] = [];
  const fetchFn = ((url: string | URL, init?: RequestInit) => {
    inits.push(init!);
    return Promise.resolve(
      url.toString().endsWith("/token")
        ? new Response(JSON.stringify({ refresh_token: "r", id_token: idTokenFor("apple-user") }))
        : new Response(""),
    );
  }) as typeof fetch;

  await revokeAppleTokens({ config, authorizationCode: "code", appleUserId: "apple-user", fetchFn });

  for (const init of inits) {
    assertEquals(new Headers(init.headers).get("Content-Type"), "application/x-www-form-urlencoded");
    assertEquals(init.signal instanceof AbortSignal, true);
  }
});
