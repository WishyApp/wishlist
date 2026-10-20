import { assertEquals, assertRejects } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { assertPublicUrl, fetchPublic, isBlockedIp, parseTargetUrl, UrlRejectedError } from "./url_guard.ts";

Deno.test("IPv4 bloquées", () => {
  for (
    const ip of [
      "0.0.0.0", "0.1.2.3", "10.0.0.1", "10.255.255.255", "127.0.0.1", "127.255.0.1",
      "100.64.0.1", "100.127.255.255", "169.254.169.254", "172.16.0.1", "172.31.255.255",
      "192.168.1.1", "192.0.0.1", "192.0.2.1", "198.18.0.1", "198.19.255.255",
      "198.51.100.1", "203.0.113.1", "224.0.0.1", "239.255.255.255", "240.0.0.1",
      "255.255.255.255",
    ]
  ) assertEquals(isBlockedIp(ip), true, ip);
});

Deno.test("IPv4 publiques", () => {
  for (
    const ip of [
      "1.1.1.1", "8.8.8.8", "100.63.255.255", "100.128.0.1", "172.15.255.255",
      "172.32.0.1", "169.253.0.1", "192.167.0.1", "198.17.0.1", "198.20.0.1", "223.255.255.255",
    ]
  ) assertEquals(isBlockedIp(ip), false, ip);
});

Deno.test("IPv6 bloquées", () => {
  for (
    const ip of [
      "::", "::1", "[::1]", "fc00::1", "fd12:3456::1", "fe80::1", "febf::1", "fec0::1",
      "ff02::1", "::ffff:127.0.0.1", "::ffff:7f00:1", "::ffff:169.254.169.254",
      "::ffff:10.0.0.1", "0:0:0:0:0:ffff:c0a8:101", "::127.0.0.1", "64:ff9b::7f00:1",
      "2002:7f00:1::1", "2001:0:1::1", "2001:db8::1", "::ffff:0:7f00:1", "100::1", "64:ff9b::a00:1",
      "2002:a9fe:a9fe::1", "4000::1",
    ]
  ) assertEquals(isBlockedIp(ip), true, ip);
});

Deno.test("IPv6 publiques", () => {
  for (
    const ip of ["2606:4700:4700::1111", "2001:4860:4860::8888", "::ffff:8.8.8.8", "64:ff9b::808:808"]
  ) assertEquals(isBlockedIp(ip), false, ip);
});

Deno.test("chaînes invalides refusées", () => {
  for (const s of ["", "abc", "1.2.3", "256.1.1.1", "1::2::3", "::g", "fe80::1%eth0"]) {
    assertEquals(isBlockedIp(s), true, s);
  }
});

Deno.test("parseTargetUrl : schémas, identifiants, ports", () => {
  assertEquals(parseTargetUrl("https://example.com/a?b=1").hostname, "example.com");
  assertEquals(parseTargetUrl("http://example.com:80/").port, "");
  for (
    const u of [
      "ftp://example.com", "file:///etc/passwd", "javascript:alert(1)", "gopher://example.com",
      "https://user:pw@example.com", "https://user@example.com", "http://example.com:6379",
      "https://example.com:8443", "not a url", "",
    ]
  ) {
    let rejected = false;
    try {
      parseTargetUrl(u);
    } catch (e) {
      rejected = e instanceof UrlRejectedError;
    }
    assertEquals(rejected, true, u);
  }
});

Deno.test("assertPublicUrl : IP littérales, formes exotiques", async () => {
  const noDns = () => Promise.reject(new Error("no dns expected"));
  for (
    const u of [
      "http://127.0.0.1/", "http://localhost.", "http://[::1]/", "http://169.254.169.254/latest/meta-data/",
      "http://2130706433/", "http://0x7f.1/", "http://0177.0.0.1/", "http://[::ffff:127.0.0.1]/",
      "http://10.0.0.5/", "https://[fd00::1]/", "http://127.1/", "http://%31%32%37.0.0.1/",
      "http://0x7f000001/", "http://[fe80::1%25eth0]/", "http://0.0.0.0/",
    ]
  ) {
    await assertRejects(() => assertPublicUrl(u, noDns), UrlRejectedError, undefined, u);
  }
  await assertPublicUrl("https://8.8.8.8/", noDns);
  await assertPublicUrl("https://[2606:4700:4700::1111]/", noDns);
});

Deno.test("assertPublicUrl : résolution DNS", async () => {
  await assertPublicUrl("https://example.com/", () => Promise.resolve(["93.184.216.34"]));
  // Une seule adresse interne suffit à refuser (A publique + AAAA interne).
  await assertRejects(
    () => assertPublicUrl("https://evil.test/", () => Promise.resolve(["93.184.216.34", "::1"])),
    UrlRejectedError,
  );
  await assertRejects(
    () => assertPublicUrl("https://evil.test/", () => Promise.resolve(["10.0.0.1"])),
    UrlRejectedError,
  );
  // Aucun enregistrement, erreur DNS, API absente : fail closed.
  await assertRejects(() => assertPublicUrl("https://nx.test/", () => Promise.resolve([])), UrlRejectedError);
  await assertRejects(() => assertPublicUrl("https://nx.test/", () => Promise.reject(new Error("x"))), UrlRejectedError);
  await assertRejects(
    () => assertPublicUrl("https://nx.test/", () => Promise.reject(new UrlRejectedError("DNS resolution unavailable"))),
    UrlRejectedError,
  );
});

/** Faux fetch : réponses par URL, et liste des URL demandées. */
function fakeFetch(routes: Record<string, () => Response>) {
  const calls: string[] = [];
  const fn = ((input: string | URL | Request) => {
    const url = input instanceof Request ? input.url : String(input);
    calls.push(url);
    const route = routes[url];
    return Promise.resolve(route ? route() : new Response("not found", { status: 404 }));
  }) as typeof fetch;
  return { fn, calls };
}

const redirect = (location: string, status = 302) => () =>
  new Response("moved", { status, headers: { location } });
const publicDns = () => Promise.resolve(["93.184.216.34"]);

Deno.test("fetchPublic : redirections relatives et absolues suivies", async () => {
  const { fn, calls } = fakeFetch({
    "https://shop.test/a": redirect("/b", 301),
    "https://shop.test/b": redirect("https://www.shop.test/c", 308),
    "https://www.shop.test/c": () => new Response("<html></html>", { status: 200 }),
  });
  const res = await fetchPublic("https://shop.test/a", {}, publicDns, fn);
  assertEquals(res.status, 200);
  assertEquals(calls, ["https://shop.test/a", "https://shop.test/b", "https://www.shop.test/c"]);
});

Deno.test("fetchPublic : redirection vers une adresse interne refusée", async () => {
  for (
    const target of [
      "http://127.0.0.1/", "http://169.254.169.254/latest/meta-data/", "http://[::1]/",
      "http://localhost:6379/", "file:///etc/passwd",
    ]
  ) {
    const { fn, calls } = fakeFetch({ "https://shop.test/": redirect(target) });
    await assertRejects(() => fetchPublic("https://shop.test/", {}, publicDns, fn), UrlRejectedError, undefined, target);
    assertEquals(calls, ["https://shop.test/"], target);
  }
  // Nom d'hôte de la redirection résolu vers une adresse interne.
  const { fn } = fakeFetch({ "https://shop.test/": redirect("https://internal.test/") });
  const dns = (h: string) => Promise.resolve(h === "internal.test" ? ["10.0.0.1"] : ["93.184.216.34"]);
  await assertRejects(() => fetchPublic("https://shop.test/", {}, dns, fn), UrlRejectedError);
});

Deno.test("fetchPublic : 5 redirections au plus", async () => {
  const routes: Record<string, () => Response> = {};
  for (let i = 0; i < 10; i++) routes[`https://shop.test/${i}`] = redirect(`/${i + 1}`);
  routes["https://shop.test/5"] = () => new Response("ok");
  assertEquals((await fetchPublic("https://shop.test/0", {}, publicDns, fakeFetch(routes).fn)).status, 200);
  routes["https://shop.test/5"] = redirect("/6");
  await assertRejects(() => fetchPublic("https://shop.test/0", {}, publicDns, fakeFetch(routes).fn), UrlRejectedError);
});

Deno.test("fetchPublic : 3xx sans Location renvoyée telle quelle, redirect manuel", async () => {
  let seenRedirect: RequestRedirect | undefined;
  const fn = ((_: string | URL | Request, init?: RequestInit) => {
    seenRedirect = init?.redirect;
    return Promise.resolve(new Response(null, { status: 304 }));
  }) as typeof fetch;
  assertEquals((await fetchPublic("https://shop.test/", { redirect: "follow" }, publicDns, fn)).status, 304);
  assertEquals(seenRedirect, "manual");
});
