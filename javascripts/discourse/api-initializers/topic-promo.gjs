import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

export default apiInitializer((api) => {
  // Parse configured promo tags
  const getPromoTags = () => {
    const raw = (settings.promo_trigger_tags || "").split("|");
    return raw.map((t) => t.trim().toLowerCase()).filter(Boolean);
  };

  // Normalize tag to a safe HTML id (kebab-case, lowercase)
  const safeSlug = (str) => {
    return (str || "")
      .toLowerCase()
      .trim()
      .replace(/[\s_]+/g, "-")
      .replace(/[^a-z0-9-]/g, "");
  };

  // Flash helper: add a transient class to trigger CSS animation
  function flashEl(el) {
    if (!el) return;
    el.classList.remove("promo-flash");
    // Force reflow so re-adding the class retriggers animation
    void el.offsetWidth;
    el.classList.add("promo-flash");

    // Clean up after animation
    el.addEventListener(
      "animationend",
      () => el.classList.remove("promo-flash"),
      { once: true }
    );
    setTimeout(() => el.classList.remove("promo-flash"), 1600);
  }

  // If hash is present and target exists, flash it
  function attemptHighlightByHash() {
    try {
      const raw = window.location.hash || "";
      const id = decodeURIComponent(raw.replace(/^#/, ""));
      if (!id) return;
      const el = document.getElementById(id);
      if (!el || !el.matches?.(".d-wrap[data-wrap][id]")) return;
      flashEl(el);
    } catch {
      // no-op
    }
  }

  // On navigation, try to highlight after render (in case target is already present)
  api.onPageChange(() => {
    schedule("afterRender", attemptHighlightByHash);
  });

  // Decorate cooked content to add anchor IDs to matching .d-wrap elements
  // This runs every time a post's cooked HTML is inserted (SPA + virtualization safe)
  api.decorateCooked(
    (elem, helper) => {
      const post = helper?.getModel?.();
      // Only process the first post
      if (!post || post.post_number !== 1) return;

      const promoTags = getPromoTags();
      if (!promoTags.length) return;

      // Convert elem to native DOM element if it's a jQuery object
      let element = elem;
      if (
        elem &&
        (typeof elem.jquery !== "undefined" || typeof elem.get === "function")
      ) {
        element = elem.get ? elem.get(0) : elem[0];
      }
      if (!element || typeof element.querySelectorAll !== "function") return;

      // Track anchors assigned within this cooked fragment (avoid duplicates)
      const assignedAnchors = new Set();

      element.querySelectorAll(".d-wrap[data-wrap]").forEach((node) => {
        const rawTag = node.getAttribute("data-wrap") || "";
        const normalizedTag = rawTag.trim().toLowerCase();
        if (!promoTags.includes(normalizedTag)) return;

        const anchor = safeSlug(normalizedTag);
        if (assignedAnchors.has(anchor)) return;

        // If a descendant already carries this id (e.g., heading anchor), move it to the wrap
        const existing = element.querySelector(`#${CSS.escape(anchor)}`);
        if (existing && existing !== node) {
          existing.removeAttribute("id");
        }

        // Assign the ID to the wrap itself
        node.id = anchor;
        assignedAnchors.add(anchor);

        // If current URL hash matches this anchor, flash after render
        if ((window.location.hash || "") === `#${anchor}`) {
          schedule("afterRender", () => flashEl(node));
        }
      });
    },
    { id: "promo-wrap-anchor", onlyStream: true }
  );
});
