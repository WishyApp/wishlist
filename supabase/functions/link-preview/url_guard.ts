// Validation des URL lues par link-preview : seules les pages web publiques
// sont acceptées. Les adresses non routables sur Internet (loopback, réseaux
// privés, link-local, métadonnées cloud...) sont refusées.

export class UrlRejectedError extends Error {}

/** Ports acceptés : ceux du web (vide = port par défaut du schéma). */
const ALLOWED_PORTS = new Set(["", "80", "443"]);

/** Lit « a.b.c.d » (seule forme que `URL` renvoie pour une IPv4). */
export function parseIPv4(s: string): number[] | null {
  const m = s.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!m) return null;
  const parts = m.slice(1).map(Number);
  return parts.every((n) => n <= 255) ? parts : null;
}

/** Lit une IPv6 (sans crochets) et renvoie ses 8 groupes de 16 bits. */
export function parseIPv6(input: string): number[] | null {
  if (!input.includes(":") || input.includes("%")) return null;
  let s = input;
  // Fin en notation IPv4 (« ::ffff:1.2.3.4 ») : convertie en deux groupes.
  const lastColon = s.lastIndexOf(":");
  if (s.slice(lastColon + 1).includes(".")) {
    const v4 = parseIPv4(s.slice(lastColon + 1));
    if (!v4) return null;
    s = `${s.slice(0, lastColon + 1)}${((v4[0] << 8) | v4[1]).toString(16)}:${((v4[2] << 8) | v4[3]).toString(16)}`;
  }
  const halves = s.split("::");
  if (halves.length > 2) return null;
  const toGroups = (h: string) => (h === "" ? [] : h.split(":"));
  const head = toGroups(halves[0]);
  const tail = halves.length === 2 ? toGroups(halves[1]) : [];
  const missing = 8 - head.length - tail.length;
  if (halves.length === 2 ? missing < 1 : missing !== 0) return null;
  const groups = [...head, ...Array(halves.length === 2 ? missing : 0).fill("0"), ...tail];
  const out = groups.map((g) => (/^[0-9a-f]{1,4}$/i.test(g) ? parseInt(g, 16) : NaN));
  return out.length === 8 && out.every((n) => !Number.isNaN(n)) ? out : null;
}

function isBlockedIPv4([a, b, c]: number[]): boolean {
  return (
    a === 0 || // 0.0.0.0/8
    a === 10 || // privé
    a === 127 || // loopback
    (a === 100 && b >= 64 && b <= 127) || // CGNAT 100.64.0.0/10
    (a === 169 && b === 254) || // link-local, dont 169.254.169.254 (métadonnées cloud)
    (a === 172 && b >= 16 && b <= 31) || // privé
    (a === 192 && b === 168) || // privé
    (a === 192 && b === 0 && c === 0) || // 192.0.0.0/24 (IETF)
    (a === 192 && b === 0 && c === 2) || // documentation
    (a === 198 && (b === 18 || b === 19)) || // benchmark
    (a === 198 && b === 51 && c === 100) || // documentation
    (a === 203 && b === 0 && c === 113) || // documentation
    a >= 224 // multicast, réservé, broadcast
  );
}

function isBlockedIPv6(g: number[]): boolean {
  const embeddedV4 = (hi: number, lo: number) => [hi >> 8, hi & 255, lo >> 8, lo & 255];
  const firstFiveZero = g.slice(0, 5).every((x) => x === 0);
  if (firstFiveZero && g[5] === 0) return true; // ::/96 : « :: », « ::1 », IPv4-compatible
  if (firstFiveZero && g[5] === 0xffff) return isBlockedIPv4(embeddedV4(g[6], g[7])); // IPv4-mapped
  // NAT64 64:ff9b::/96 et 6to4 2002::/16 embarquent une IPv4.
  if (g[0] === 0x64 && g[1] === 0xff9b && g.slice(2, 6).every((x) => x === 0)) {
    return isBlockedIPv4(embeddedV4(g[6], g[7]));
  }
  if (g[0] === 0x2002) return isBlockedIPv4(embeddedV4(g[1], g[2]));
  // Hors 2000::/3 (seul bloc unicast global attribué) : unique local fc00::/7,
  // link-local fe80::/10, multicast ff00::/8, ::ffff:0:0/96, 100::/64... refusés.
  if ((g[0] & 0xe000) !== 0x2000) return true;
  return (
    (g[0] === 0x2001 && g[1] === 0) || // Teredo 2001::/32
    (g[0] === 0x2001 && g[1] === 0xdb8) // documentation 2001:db8::/32
  );
}

/**
 * Vrai si l'adresse (texte IPv4 ou IPv6, crochets tolérés) est à refuser.
 * Une chaîne qui n'est pas une IP valide est refusée (fail closed).
 */
export function isBlockedIp(ip: string): boolean {
  const s = ip.replace(/^\[|\]$/g, "");
  const v4 = parseIPv4(s);
  if (v4) return isBlockedIPv4(v4);
  const v6 = parseIPv6(s);
  return v6 ? isBlockedIPv6(v6) : true;
}

/**
 * Valide la forme de l'URL : http(s), sans identifiants, port web.
 * `new URL` normalise les IPv4 exotiques (« 2130706433 », « 0x7f.1 ») en
 * « 127.0.0.1 » : la vérification d'IP voit donc toujours la forme canonique.
 */
export function parseTargetUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new UrlRejectedError("Invalid url");
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new UrlRejectedError("Only http and https urls are allowed");
  }
  if (url.username || url.password) {
    throw new UrlRejectedError("Credentials in url are not allowed");
  }
  if (!ALLOWED_PORTS.has(url.port)) {
    throw new UrlRejectedError("Port not allowed");
  }
  return url;
}

export type DnsResolver = (hostname: string) => Promise<string[]>;

const DNS_TIMEOUT_MS = 3000;

/** Résolution A + AAAA via Deno.resolveDns ; échoue si l'API est absente. */
export const defaultResolver: DnsResolver = async (hostname) => {
  if (typeof Deno?.resolveDns !== "function") {
    throw new UrlRejectedError("DNS resolution unavailable");
  }
  const signal = AbortSignal.timeout(DNS_TIMEOUT_MS);
  const [a, aaaa] = await Promise.allSettled([
    Deno.resolveDns(hostname, "A", { signal }),
    Deno.resolveDns(hostname, "AAAA", { signal }),
  ]);
  return [
    ...(a.status === "fulfilled" ? a.value : []),
    ...(aaaa.status === "fulfilled" ? aaaa.value : []),
  ];
};

/**
 * Accepte l'URL seulement si sa forme est valide et si TOUTES les adresses
 * de son hôte sont publiques. À appeler pour l'URL initiale et pour chaque
 * redirection.
 *
 * Limite connue (DNS rebinding) : la résolution faite ici et celle que fait
 * ensuite `fetch` sont indépendantes, l'adresse vérifiée n'est donc pas
 * garantie identique à l'adresse contactée si les réponses DNS du domaine
 * changent entre les deux. Deno ne permet pas d'imposer l'IP résolue à un
 * `fetch` HTTPS sans casser SNI et certificat. Atténuations : ports 80/443
 * seulement, utilisateur authentifié, et seuls le titre et l'URL d'image
 * extraits sont renvoyés (jamais la réponse brute).
 */
export async function assertPublicUrl(
  raw: string,
  resolver: DnsResolver = defaultResolver,
): Promise<URL> {
  const url = parseTargetUrl(raw);
  const host = url.hostname.replace(/^\[|\]$/g, "");
  const isLiteral = parseIPv4(host) !== null || host.includes(":");
  let addresses: string[];
  if (isLiteral) {
    addresses = [host];
  } else {
    try {
      addresses = await resolver(host);
    } catch (e) {
      if (e instanceof UrlRejectedError) throw e;
      throw new UrlRejectedError("Host could not be resolved");
    }
    if (addresses.length === 0) throw new UrlRejectedError("Host could not be resolved");
  }
  if (addresses.some(isBlockedIp)) throw new UrlRejectedError("Host not allowed");
  return url;
}

const MAX_REDIRECTS = 5;

/**
 * `fetch` qui suit les redirections lui-même (5 au plus) et valide chaque
 * URL, initiale comme cible de redirection, avec [assertPublicUrl].
 */
export async function fetchPublic(
  targetUrl: string,
  init: RequestInit,
  resolver: DnsResolver = defaultResolver,
  fetchFn: typeof fetch = fetch,
): Promise<Response> {
  let current = targetUrl;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    const url = await assertPublicUrl(current, resolver);
    const res = await fetchFn(url, { ...init, redirect: "manual" });
    const location = res.headers.get("location");
    if (res.status < 300 || res.status >= 400 || !location) return res;
    await res.body?.cancel();
    current = new URL(location, url).href;
  }
  throw new UrlRejectedError("Too many redirects");
}
