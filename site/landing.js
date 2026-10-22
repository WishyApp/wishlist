// Accueil wishy-app.fr : langue (FR par défaut, EN sur demande ou selon le
// navigateur, cf. lang.js) et boutons des stores (stores.js).
"use strict";

// Le français est écrit dans index.html ; seules les traductions sont ici.
const EN = {
  skip: "Skip to content",
  navLabel: "Navigation",
  navHow: "How it works",
  navUs: "Who we are",
  navDownload: "Download",
  heroTitle: "Gifts, sorted<br /><em>among friends.</em><br />The surprise,<br />all yours.",
  heroLede:
    "Make your wishlists and share them. Your people split the gifts between themselves, no duplicates, and without telling you a thing.",
  step1: "Your wishes",
  step2: "Your people",
  step3: "The secret",
  step4: "The big day",
  sub1: "One list per occasion.",
  sub2: "One link, and everyone can see it.",
  sub3: "They book. You don't see a thing.",
  sub4: "Your gifts to give, right at hand.",
  loopCaption: "The Wishy cycle in four steps: your wishes, your people, the secret, the big day.",
  altHome: "The Wishlists screen of the app, with four lists: My birthday, Christmas 2026, Gift ideas, New flat.",
  altFriendWl: "Olivia's housewarming list opened by a friend: a stoneware mug and a scented candle.",
  altFriendWish: "One of Olivia's wishes seen by a friend: a scented candle at €32, with the I want to give it button.",
  altBooked: "The Bookings screen: one gift for Jack, one for Olivia, €210 in total.",
  altBooked2: "The Bookings screen: a leather watch for Jack, a backpack for Olivia, €210 in total.",
  altWl: "The My birthday list: wireless headphones, handbag, smartwatch, sneakers, with their prices.",
  stepOf1: "Step 1 of 4:",
  stepOf2: "Step 2 of 4:",
  stepOf3: "Step 3 of 4:",
  stepOf4: "Step 4 of 4:",
  enviesTitle: "One wishlist per occasion.",
  enviesText1: "Birthday, Christmas, housewarming: every occasion gets its list, every list its colour.",
  enviesText2:
    "Spotted something you like in an online shop? Share it to Wishy from any app: photo, price and link come along on their own.",
  chatHead: "Family 🎄",
  chatQ: "What do you want for Christmas this year?",
  chatA: "It's all in here 👇",
  chatCardTitle: "A wishlist is waiting for you on Wishy",
  chatR: "Perfect, I'll look tonight",
  prochesTitle: "One link, and the whole family is in.",
  prochesText1:
    "Drop your list in the family group chat, by text or by email. The link opens the app, or invites them to install it.",
  prochesText2: "Add your friends in Wishy to find all their lists in one place, before every birthday.",
  secretTitle: "Your friends know. <em>You don't.</em>",
  secretLede:
    "When a friend books a wish, the others see it and don't buy it twice. You just see your list.",
  viewMe: "Seen by you",
  viewThem: "Seen by your friends",
  viewLabel: "Choose the view",
  sideMe: "My birthday, seen by you",
  countMe: "Booked: ?",
  sideThem: "The same list, seen by your friends",
  countThem: "Booked: 2",
  hidden: "Booking hidden",
  w1: "Wireless headphones",
  w2: "Red handbag",
  w3: "Smartwatch",
  w4: "Black sneakers",
  byHugo: "Hugo's on it",
  byLea: "Léa's on it",
  free: "Free",
  jourTitle: "On the big day, you know what to buy.",
  jourText:
    "Everything you booked for others is sorted by friend, with the total budget. No more “what was it again, for Léa?” in the shop aisle.",
  noteFriend: "sorted by friend",
  noteBudget: "the total budget",
  nousTitle: "Two brothers, and gifts nobody could coordinate.",
  nousText1:
    "We're Raphaël and Tanguy. Birthdays, then Christmas: several occasions in a row, and duplicate gifts every time. Wishes were passed around by email or word of mouth, and working out who was getting what was a real headache.",
  nousText2:
    "So we built Wishy, in the evenings and at weekends, also for the fun of building something together. Free, no ads, and your data isn't sold.",
  finalTitle: "No more duplicates.",
  finalPromise: "Free · no ads · your data isn't sold",
  madeBy: "made by Raphaël & Tanguy",
  legalLabel: "Legal links",
  privacy: "Privacy (in French)",
  terms: "Terms of use (in French)",
};

const STORE_LABELS = {
  fr: { appStore: "Télécharger sur l'App Store", playStore: "Disponible sur Google Play", soon: "bientôt" },
  en: { appStore: "Download on the App Store", playStore: "Get it on Google Play", soon: "coming soon" },
};

const STORE_NAMES = { appStore: "App Store", playStore: "Google Play" };

const remember = window.WISHY_LANG.remember;

function applyLang(lang) {
  const isEn = lang === "en";
  document.documentElement.lang = lang;

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const fr = remember(element, "fr", element.textContent);
    const en = EN[element.dataset.i18n];
    element.textContent = isEn && en ? en : fr;
  });

  // Textes avec balises (titres avec <em>) : chaînes écrites dans ce fichier.
  document.querySelectorAll("[data-i18n-html]").forEach((element) => {
    const fr = remember(element, "frHtml", element.innerHTML);
    const en = EN[element.dataset.i18nHtml];
    element.innerHTML = isEn && en ? en : fr;
  });

  document.querySelectorAll("[data-i18n-attr]").forEach((element) => {
    const [attribute, key] = element.dataset.i18nAttr.split(":");
    const fr = remember(element, "frAttr", element.getAttribute(attribute) || "");
    element.setAttribute(attribute, isEn && EN[key] ? EN[key] : fr);
  });

  window.WISHY_LANG.applyImages(lang);

  document.querySelectorAll("[data-lang-toggle]").forEach((button) => {
    button.textContent = isEn ? "FR" : "EN";
    button.setAttribute("aria-label", isEn ? "FR, passer en français" : "EN, switch to English");
  });

  tightenPunctuation();
  document.title = isEn ? "Wishy · Gifts, sorted between friends" : "Wishy · Les cadeaux, entre amis";
  renderStores(lang);
}

function tightenPunctuation() {
  document.querySelectorAll("h1, h2").forEach((heading) => {
    const walker = document.createTreeWalker(heading, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) {
      if (!walker.currentNode.parentElement.closest(".punct, .visually-hidden")) {
        nodes.push(walker.currentNode);
      }
    }
    nodes.forEach((node) => {
      const parts = node.textContent.split(/([.,])/);
      if (parts.length === 1) {
        return;
      }
      node.replaceWith(
        ...parts.filter(Boolean).map((part) => {
          if (part !== "." && part !== ",") {
            return part;
          }
          const span = document.createElement("span");
          span.className = "punct";
          span.textContent = part;
          return span;
        }),
      );
    });
  });
}

function renderStores(lang) {
  const stores = window.WISHY_STORES || {};
  const labels = STORE_LABELS[lang];

  document.querySelectorAll("[data-stores]").forEach((row) => {
    row.replaceChildren(
      ...["appStore", "playStore"].map((key) => {
        const url = stores[key];
        if (url) {
          const link = document.createElement("a");
          link.className = "store";
          link.href = url;
          link.textContent = labels[key];
          return link;
        }
        const soon = document.createElement("span");
        soon.className = "store store-soon";
        const note = document.createElement("small");
        note.textContent = "· " + labels.soon;
        soon.append(STORE_NAMES[key] + " ", note);
        return soon;
      }),
    );
  });
}

// Les tracés entre les étapes se dessinent quand ils arrivent à l'écran. Sans
// IntersectionObserver ou en mouvement réduit, ils restent dessinés.
function drawTrailsOnScroll() {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduceMotion || !("IntersectionObserver" in window)) {
    return;
  }
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-drawn");
          observer.unobserve(entry.target);
        }
      });
    },
    { rootMargin: "0px 0px -20% 0px" },
  );
  document.documentElement.classList.add("trails-anim");
  document.querySelectorAll(".trail").forEach((trail) => observer.observe(trail));
}

function init() {
  drawTrailsOnScroll();
  let lang = window.WISHY_LANG.initial();
  applyLang(lang);

  document.querySelectorAll("[data-lang-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      lang = lang === "fr" ? "en" : "fr";
      window.WISHY_LANG.store(lang);
      applyLang(lang);
    });
  });
}

init();
