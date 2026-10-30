// USWDS in-page nav marks the last fully visible heading in its observer
// root, which sits ahead of the reading line when scrolling down. Drive
// usa-current from the last heading that has crossed that line. Clicks use
// getBoundingClientRect so flex layout does not overshoot.

// Only show the in-page navigation when 3 or more primary items are present.
// On resource pages, place that nav above the related-communities block and
// hide headings that live inside a ring component.

function headingForNavLink(link) {
  const id = decodeURIComponent(link.hash.replace(/^#/, ""));
  const target = document.getElementById(id);
  if (!target) return null;
  return target.closest("h1, h2, h3, h4, h5, h6") || target;
}

function navScrollOffset(nav) {
  if (nav.dataset.scrollOffset !== undefined && nav.dataset.scrollOffset !== "") {
    return Number(nav.dataset.scrollOffset);
  }

  // Match html { scroll-padding-top } when a nav does not set its own offset.
  const padding = Number.parseFloat(
    window.getComputedStyle(document.documentElement).scrollPaddingTop
  );
  return Number.isFinite(padding) ? padding : 0;
}

function visibleNavLinks(nav) {
  return [...nav.querySelectorAll(".usa-in-page-nav__link")].filter((link) => {
    const item = link.closest(".usa-in-page-nav__item");
    if (!item) return true;
    return window.getComputedStyle(item).display !== "none";
  });
}

function syncInPageNavCurrent(nav) {
  const links = visibleNavLinks(nav);
  if (!links.length) return;

  // Pick up the next heading a little before it reaches the click offset so
  // the active item matches what is already in the reading area.
  const line = navScrollOffset(nav) + 36;
  let activeHref = links[0].getAttribute("href");

  links.forEach((link) => {
    const heading = headingForNavLink(link);
    if (!heading) return;
    if (heading.getBoundingClientRect().top <= line) {
      activeHref = link.getAttribute("href");
    }
  });

  links.forEach((link) => {
    link.classList.toggle("usa-current", link.getAttribute("href") === activeHref);
  });
}

function scrollHeadingIntoOffset(heading, offset, behavior) {
  const top = heading.getBoundingClientRect().top + window.scrollY - offset;
  window.scrollTo({ top: Math.max(0, top), behavior });
}

function followNavLink(event, nav) {
  const link = event.target.closest(".usa-in-page-nav__link");
  if (!link || !nav.contains(link)) return false;

  const heading = headingForNavLink(link);
  if (!heading) return false;

  event.preventDefault();
  event.stopImmediatePropagation();
  scrollHeadingIntoOffset(heading, navScrollOffset(nav), "smooth");
  if (link.hash && window.location.hash !== link.hash) {
    window.history.pushState(null, "", link.hash);
  }

  if (event.type === "keydown") {
    heading.setAttribute("tabindex", "0");
    heading.focus({ preventScroll: true });
    heading.addEventListener(
      "blur",
      () => {
        heading.setAttribute("tabindex", "-1");
      },
      { once: true }
    );
  }

  syncInPageNavCurrent(nav);
  return true;
}

function arrangeInPageNav() {
  if (document.documentElement.dataset.inPageNavArranged === "true") return;

  const inPageNav = document.querySelector(".usa-in-page-nav__nav");
  const inPageNavHeader = document.querySelector(".usa-in-page-nav__heading");
  const navItems = document.querySelectorAll(
    "li.usa-in-page-nav__item:not(.usa-in-page-nav__item--sub-item)"
  );

  if (!inPageNav || !navItems.length) return;

  document.documentElement.dataset.inPageNavArranged = "true";

  if (navItems.length < 3) {
    inPageNav.style.display = "none";
    return;
  }

  const relatedItems = document.querySelector("[data-related-items]");
  if (!relatedItems || !inPageNavHeader) return;

  inPageNavHeader.removeAttribute("tabindex");
  relatedItems.before(inPageNav);

  // Hide nav links when they are a child of a ring component.
  navItems.forEach((item) => {
    const link = item.querySelector("a");
    if (!link) return;
    const targetId = link.getAttribute("href").slice(1);
    const targetElement = document.getElementById(targetId);

    if (targetElement && targetElement.closest(".dg-ring")) {
      item.style.display = "none";
    }
  });
}

function correctHashPosition(nav) {
  if (!window.location.hash) return;
  const link = visibleNavLinks(nav).find((item) => item.hash === window.location.hash);
  const heading = link && headingForNavLink(link);
  if (!heading) return;
  scrollHeadingIntoOffset(heading, navScrollOffset(nav), "auto");
}

let scrollListenerBound = false;

function bindScrollSync() {
  if (scrollListenerBound) return;
  scrollListenerBound = true;

  let applying = false;
  const apply = () => {
    if (applying) return;
    applying = true;
    document.querySelectorAll(".usa-in-page-nav").forEach((nav) => {
      if (nav.dataset.scrollSpyBound === "true") {
        syncInPageNavCurrent(nav);
      }
    });
    applying = false;
  };

  let frame = 0;
  const onScroll = () => {
    if (frame) return;
    frame = window.requestAnimationFrame(() => {
      frame = 0;
      apply();
      window.requestAnimationFrame(apply);
    });
  };

  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("hashchange", apply);
}

function startInPageNavSync() {
  arrangeInPageNav();

  document.querySelectorAll(".usa-in-page-nav").forEach((nav) => {
    if (nav.dataset.scrollSpyBound === "true") return;

    const navList = nav.querySelector(".usa-in-page-nav__nav");
    if (!navList || navList.style.display === "none") return;
    if (!nav.querySelector(".usa-in-page-nav__link")) return;

    nav.dataset.scrollSpyBound = "true";
    bindScrollSync();
    correctHashPosition(nav);

    let applying = false;
    const apply = () => {
      if (applying) return;
      applying = true;
      syncInPageNavCurrent(nav);
      applying = false;
    };

    nav.addEventListener(
      "click",
      (event) => {
        followNavLink(event, nav);
      },
      true
    );

    nav.addEventListener(
      "keydown",
      (event) => {
        if (event.key !== "Enter") return;
        followNavLink(event, nav);
      },
      true
    );

    new MutationObserver(apply).observe(nav, {
      subtree: true,
      attributes: true,
      attributeFilter: ["class"],
    });

    apply();
  });
}

const observer = new MutationObserver(startInPageNavSync);
observer.observe(document.documentElement, { childList: true, subtree: true });

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", startInPageNavSync);
} else {
  startInPageNavSync();
}

window.addEventListener("load", startInPageNavSync);
