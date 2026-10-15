// Seeds demo accounts on the DEV Supabase project (store screenshots), through
// the public API with the anon key, exactly like the app does.
// Usage: STORE_SHOTS_EMAIL_TEMPLATE='me+wishy-demo-{key}@example.com' node seed.mjs fr|en
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const DEV_PROJECT_REF = 'qedynftuclpdisocgzuv';
const ENV_FILE = path.join(HERE, '..', '..', 'wishlist', 'env', '.env.dev');
const CACHE = path.join(HERE, '.image-cache');
const ACC = path.join(HERE, '.accounts.json');
const IDS = path.join(HERE, '.ids.json');

const lang = process.argv[2];
const emailTemplate = process.env.STORE_SHOTS_EMAIL_TEMPLATE;
if (!['fr', 'en'].includes(lang)) throw new Error('usage: node seed.mjs fr|en');
if (!emailTemplate?.includes('{key}')) {
  throw new Error("set STORE_SHOTS_EMAIL_TEMPLATE, e.g. 'me+wishy-demo-{key}@example.com'");
}

const envText = fs.readFileSync(ENV_FILE, 'utf8');
const env = Object.fromEntries(
  envText.split('\n').filter((l) => /^\w+\s*=/.test(l))
    .map((l) => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^['"]|['"]$/g, '')]; }),
);
if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) {
  throw new Error(`${ENV_FILE} has no SUPABASE_URL / SUPABASE_ANON_KEY (still encrypted? see the transcrypt section of the root README)`);
}
const URL_ = env.SUPABASE_URL, ANON = env.SUPABASE_ANON_KEY;
if (!URL_.includes(DEV_PROJECT_REF)) throw new Error('refusing to run: not the dev Supabase project');

// Unsplash photo ids
const PHOTOS = {
  headphones: '1505740420928-5e560c06d30e', watch: '1523275335684-37898b6baf30',
  sneakers: '1491553895911-0055eca6402d', bag: '1584917865442-de89df76afd3',
  candle: '1603006905003-be475563bc59', bottle: '1602143407151-7111542de6e8',
  sunglasses: '1572635196237-14b3f281503f', plant: '1485955900006-10f4d324d411',
  ceramics: '1610701596007-11502861dcfa', chair: '1592078615290-033ee584e267',
  mug: '1514228742587-6b1558fcca3d', backpack: '1553062407-98eeb64c6a62',
  leatherwatch: '1495856458515-0637185db551',
};

async function ensureImages() {
  fs.mkdirSync(CACHE, { recursive: true });
  for (const [name, id] of Object.entries(PHOTOS)) {
    const full = path.join(CACHE, `${name}.webp`), thumb = path.join(CACHE, `${name}_thumb.webp`);
    if (fs.existsSync(full) && fs.existsSync(thumb)) continue;
    const jpg = path.join(CACHE, `${name}.jpg`);
    const res = await fetch(`https://images.unsplash.com/photo-${id}?w=1024&h=1024&fit=crop&q=85&fm=jpg`);
    if (!res.ok) throw new Error(`download ${name}: HTTP ${res.status}`);
    fs.writeFileSync(jpg, Buffer.from(await res.arrayBuffer()));
    execFileSync('cwebp', ['-quiet', '-q', '90', jpg, '-o', full]);
    execFileSync('cwebp', ['-quiet', '-q', '80', '-resize', '256', '256', jpg, '-o', thumb]);
    fs.rmSync(jpg);
  }
}

const readJson = (f) => (fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, 'utf8')) : {});
const accounts = readJson(ACC);

const BLUE = '#69abe9', PURPLE = '#9665e5', YELLOW = '#dbcd4d', GREEN = '#57bd87';
const w = (name, price, img, extra = {}) => ({ name, price, img, ...extra });

const DATA = {
  fr: {
    main: { key: 'fr-main', pseudo: 'Camille' },
    friends: [{ key: 'fr-lea', pseudo: 'Léa' }, { key: 'fr-hugo', pseudo: 'Hugo' }],
    lists: {
      'fr-main': [
        { name: 'Mon anniversaire 🎂', color: PURPLE, end: '2026-11-21', wishes: [
          w('Casque audio sans fil', 129, 'headphones', { fav: true, desc: 'Réduction de bruit active, le jaune si possible !' }),
          w('Montre connectée', 199, 'watch', { desc: 'Bracelet blanc, taille M' }),
          w('Baskets noires', 95, 'sneakers', { desc: 'Pointure 39' }),
          w('Sac à main rouge', 160, 'bag', { fav: true }),
        ] },
        { name: 'Noël 2026 🎄', color: GREEN, end: '2026-12-25', wishes: [
          w('Bougie parfumée', 32, 'candle', { desc: 'Senteur bois de santal' }),
          w('Gourde isotherme', 25, 'bottle'),
          w('Lunettes de soleil', 89, 'sunglasses', { fav: true }),
        ] },
        { name: 'Idées cadeaux 🎁', color: BLUE, wishes: [
          w('Mug en grès', 14, 'mug'), w('Sac à dos', 70, 'backpack'), w('Montre en cuir', 140, 'leatherwatch'),
        ] },
        { name: 'Nouvel appart 🏡', color: YELLOW, wishes: [
          w('Plante grasse', 18, 'plant'),
          w('Set de tasses en céramique', 45, 'ceramics', { desc: 'Pour les cafés du dimanche' }),
          w('Chaise scandinave', 79, 'chair', { qty: 2 }),
        ] },
      ],
      'fr-lea': [
        { name: 'Crémaillère de Léa 🏠', color: BLUE, end: '2026-11-08', wishes: [
          w('Mug en grès', 14, 'mug'), w('Sac à dos', 70, 'backpack'),
          w('Bougie parfumée', 32, 'candle', { desc: 'Figue ou feu de bois, pour le salon 🕯️' }),
        ] },
      ],
      'fr-hugo': [
        { name: 'Les 25 ans de Hugo 🎉', color: GREEN, end: '2026-11-30', wishes: [
          w('Montre en cuir', 140, 'leatherwatch'), w('Gourde isotherme', 25, 'bottle'), w('Lunettes de soleil', 89, 'sunglasses'),
        ] },
      ],
    },
    bookings: [['fr-lea', 'Sac à dos'], ['fr-hugo', 'Montre en cuir']],
    // what each capture shows: [list owner, list name, wish name | null]
    shots: {
      wl: ['fr-main', 'Mon anniversaire 🎂', null],
      wish: ['fr-main', 'Mon anniversaire 🎂', 'Casque audio sans fil'],
      friendwish: ['fr-lea', 'Crémaillère de Léa 🏠', 'Bougie parfumée'],
    },
  },
  en: {
    main: { key: 'en-main', pseudo: 'Emma' },
    friends: [{ key: 'en-olivia', pseudo: 'Olivia' }, { key: 'en-jack', pseudo: 'Jack' }],
    lists: {
      'en-main': [
        { name: 'My birthday 🎂', color: PURPLE, end: '2026-11-21', wishes: [
          w('Wireless headphones', 129, 'headphones', { fav: true, desc: 'Noise cancelling, the yellow ones if possible!' }),
          w('Smartwatch', 199, 'watch', { desc: 'White strap, size M' }),
          w('Black sneakers', 95, 'sneakers', { desc: 'Size 6' }),
          w('Red handbag', 160, 'bag', { fav: true }),
        ] },
        { name: 'Christmas 2026 🎄', color: GREEN, end: '2026-12-25', wishes: [
          w('Scented candle', 32, 'candle', { desc: 'Sandalwood scent' }),
          w('Insulated bottle', 25, 'bottle'),
          w('Sunglasses', 89, 'sunglasses', { fav: true }),
        ] },
        { name: 'Gift ideas 🎁', color: BLUE, wishes: [
          w('Stoneware mug', 14, 'mug'), w('Backpack', 70, 'backpack'), w('Leather watch', 140, 'leatherwatch'),
        ] },
        { name: 'New apartment 🏡', color: YELLOW, wishes: [
          w('Succulent plant', 18, 'plant'),
          w('Ceramic cup set', 45, 'ceramics', { desc: 'For slow Sunday coffees' }),
          w('Scandinavian chair', 79, 'chair', { qty: 2 }),
        ] },
      ],
      'en-olivia': [
        { name: "Olivia's housewarming 🏠", color: BLUE, end: '2026-11-08', wishes: [
          w('Stoneware mug', 14, 'mug'), w('Backpack', 70, 'backpack'),
          w('Scented candle', 32, 'candle', { desc: 'Fig or woodfire, for the living room 🕯️' }),
        ] },
      ],
      'en-jack': [
        { name: "Jack's 25th 🎉", color: GREEN, end: '2026-11-30', wishes: [
          w('Leather watch', 140, 'leatherwatch'), w('Insulated bottle', 25, 'bottle'), w('Sunglasses', 89, 'sunglasses'),
        ] },
      ],
    },
    bookings: [['en-olivia', 'Backpack'], ['en-jack', 'Leather watch']],
    shots: {
      wl: ['en-main', 'My birthday 🎂', null],
      wish: ['en-main', 'My birthday 🎂', 'Wireless headphones'],
      friendwish: ['en-olivia', "Olivia's housewarming 🏠", 'Scented candle'],
    },
  },
}[lang];

const client = () => createClient(URL_, ANON, { auth: { persistSession: false } });

async function login(key, pseudo) {
  const c = client();
  if (!accounts[key]) {
    accounts[key] = {
      email: emailTemplate.replace('{key}', key),
      password: crypto.randomBytes(9).toString('base64url'),
      pseudo,
    };
    const { error } = await c.auth.signUp({ email: accounts[key].email, password: accounts[key].password });
    if (error) throw new Error(`signUp ${key}: ${error.message}`);
    fs.writeFileSync(ACC, JSON.stringify(accounts, null, 2), { mode: 0o600 });
  }
  const { data, error } = await c.auth.signInWithPassword({ email: accounts[key].email, password: accounts[key].password });
  if (error) throw new Error(`signIn ${key}: ${error.message}`);
  const uid = data.user.id;
  const { data: prof } = await c.from('profiles').select('id').eq('id', uid).maybeSingle();
  if (!prof) {
    const { error: e } = await c.from('profiles').insert({ id: uid, pseudo });
    if (e) throw new Error(`profile ${key}: ${e.message}`);
  }
  return { c, uid };
}

await ensureImages();

const s = {};
for (const u of [DATA.main, ...DATA.friends]) s[u.key] = await login(u.key, u.pseudo);

// friendships main <-> each friend, accepted by the main user
for (const f of DATA.friends) {
  const me = s[DATA.main.key], fr = s[f.key];
  const { data: existing } = await me.c.from('friendships').select('id,status')
    .or(`and(requester_id.eq.${me.uid},receiver_id.eq.${fr.uid}),and(requester_id.eq.${fr.uid},receiver_id.eq.${me.uid})`);
  let id = existing?.[0]?.id;
  if (!id) {
    const { data, error } = await fr.c.from('friendships').insert({ requester_id: fr.uid, receiver_id: me.uid }).select('id').single();
    if (error) throw new Error(`friendship: ${error.message}`);
    id = data.id;
  }
  const { error } = await me.c.from('friendships').update({ status: 'accepted' }).eq('id', id);
  if (error) throw new Error(`accept: ${error.message}`);
}

// wishlists + wishes (the demo users' own lists are wiped first, so reruns are clean)
const wishIds = {}, listIds = {};
for (const [key, lists] of Object.entries(DATA.lists)) {
  const { c, uid } = s[key];
  const { error: eDel } = await c.from('wishlists').delete().eq('id_owner', uid);
  if (eDel) throw new Error(`cleanup ${key}: ${eDel.message}`);
  const { count } = await c.from('wishlists').select('id', { count: 'exact', head: true }).eq('id_owner', uid);
  if (count) throw new Error(`cleanup ${key}: ${count} lists left`);
  for (const [order, l] of lists.entries()) {
    const { data: wl, error } = await c.from('wishlists').insert({
      name: l.name, id_owner: uid, updated_by: uid, color: l.color, visibility: 'public',
      end_date: l.end ? new Date(l.end).toISOString() : null, order,
    }).select('id').single();
    if (error) throw new Error(`wishlist ${l.name}: ${error.message}`);
    listIds[`${key}/${l.name}`] = wl.id;
    for (const x of l.wishes) {
      const { data: wish, error: e1 } = await c.from('wishs').insert({
        name: x.name, description: x.desc ?? '', price: x.price, is_favourite: !!x.fav,
        quantity: x.qty ?? 1, wishlist_id: wl.id, updated_by: uid,
      }).select('id').single();
      if (e1) throw new Error(`wish ${x.name}: ${e1.message}`);
      const base = `${wish.id}/wish_image_${Date.now()}`;
      for (const [suffix, file] of [['', `${x.img}.webp`], ['_thumb', `${x.img}_thumb.webp`]]) {
        const { error: e2 } = await c.storage.from('wish-images').upload(`${base}${suffix}.webp`,
          fs.readFileSync(path.join(CACHE, file)), { contentType: 'image/webp', upsert: true });
        if (e2) throw new Error(`upload ${x.name}: ${e2.message}`);
      }
      const { error: e3 } = await c.from('wishs').update({ icon_url: `${base}.webp` }).eq('id', wish.id);
      if (e3) throw new Error(`icon ${x.name}: ${e3.message}`);
      wishIds[`${key}/${l.name}/${x.name}`] = wish.id;
    }
  }
}

const me = s[DATA.main.key];
for (const [owner, name] of DATA.bookings) {
  const listName = DATA.lists[owner][0].name;
  const { error } = await me.c.from('wish_taken_by_user').insert({ user_id: me.uid, wish_id: wishIds[`${owner}/${listName}/${name}`], quantity: 1 });
  if (error) throw new Error(`booking ${name}: ${error.message}`);
}
// a friend books one of the main user's wishes too
{
  const f = s[DATA.friends[0].key];
  const mainList = DATA.lists[DATA.main.key][0];
  const { error } = await f.c.from('wish_taken_by_user').insert({
    user_id: f.uid, wish_id: wishIds[`${DATA.main.key}/${mainList.name}/${mainList.wishes[1].name}`], quantity: 1,
  });
  if (error) throw new Error(`friend booking: ${error.message}`);
}

// routes consumed by capture.sh
const routes = { home: '/', booked: '/?tab=2' };
for (const [shot, [owner, listName, wishName]] of Object.entries(DATA.shots)) {
  const listId = listIds[`${owner}/${listName}`];
  if (!wishName) { routes[shot] = `/wishlist/${listId}`; continue; }
  const wid = wishIds[`${owner}/${listName}/${wishName}`];
  routes[shot] = `/wishlist/${listId}/wish/${wid}?wish-ids=${wid}${owner === DATA.main.key ? '&is-my-wishlist=true' : ''}`;
}

const ids = readJson(IDS);
ids[lang] = {
  account: DATA.main.key,
  user: me.uid,
  friends: Object.fromEntries(DATA.friends.map((f) => [f.pseudo, s[f.key].uid])),
  lists: listIds,
  wishes: wishIds,
  routes,
};
fs.writeFileSync(IDS, JSON.stringify(ids, null, 2), { mode: 0o600 });
console.log(`seeded ${lang}: main pseudo "${DATA.main.pseudo}", credentials in .accounts.json`);
