import { apiInitializer } from "discourse/lib/api";
import { iconHTML } from "discourse/lib/icon-library";


export default apiInitializer((api) => {
  // Parse configured promo tags
  const getPromoTags = () => {
    const raw = (settings.promo_trigger_tags || "").split("|");
    return raw
      .map((t) => t.trim().toLowerCase())
      .filter(Boolean);
  };

  // Normalize tag to a safe HTML id (kebab-case, lowercase)
  const safeSlug = (str) => {
    return (str || "")
      .toLowerCase()
      .trim()
      .replace(/[\s_]+/g, "-")
      .replace(/[^a-z0-9-]/g, "");
  };

  // Track processed posts to avoid reprocessing
  const processedPosts = new Set();

  // Clear state on page change
  api.onPageChange(() => {
    processedPosts.clear();
  });

  // Decorate cooked content to add anchor IDs to matching .d-wrap elements
  api.decorateCooked(
    (elem, helper) => {
      const post = helper?.getModel?.();

      // Only process the first post
      if (!post || post.post_number !== 1) {
        return;
      }

      // Avoid reprocessing the same post
      if (processedPosts.has(post.id)) {
        return;
      }
      processedPosts.add(post.id);

      const promoTags = getPromoTags();
      if (!promoTags.length) {
        return;
      }

      // Convert elem to native DOM element if it's a jQuery object
      let element = elem;

      // Check if it's a jQuery object
      if (elem && (typeof elem.jquery !== "undefined" || typeof elem.get === "function")) {
        // It's a jQuery object, get the native DOM element
        element = elem.get ? elem.get(0) : elem[0];
      }

      // Guard: ensure we have a valid DOM element with querySelectorAll
      if (!element ||
          typeof element !== "object" ||
          typeof element.querySelectorAll !== "function") {
        return;
      }

      // Track which anchor IDs we've already assigned (one per tag)
      const assignedAnchors = new Set();

      // Find all .d-wrap elements with data-wrap attribute
      element.querySelectorAll(".d-wrap[data-wrap]").forEach((node) => {
        const rawTag = node.getAttribute("data-wrap") || "";
        const normalizedTag = rawTag.trim().toLowerCase();

        // Check if this wrap's tag matches any promo trigger tag
        if (!promoTags.includes(normalizedTag)) {
          return;
        }


        // Badge support: set CSS var for icon and inject icon element
        const badgeText = node.getAttribute("data-badge");
        if (badgeText && badgeText.trim()) {
          try {
            const iconName = (settings.promo_button_icon || "gift").trim() || "gift";
            const svgIcon = iconHTML(iconName);
            const dataUrl = `url("data:image/svg+xml;utf8,${encodeURIComponent(svgIcon)}")`;
            node.style.setProperty("--promo-badge-icon", dataUrl);
          } catch (e) {
            // Fallback: proceed without icon if generation fails
            // eslint-disable-next-line no-console
            console.warn("[Topic Promo] Failed to set badge icon:", e);
          }

          // Ensure a single icon element exists (idempotent)
          if (!node.querySelector(":scope > .promo-wrap__badge-icon")) {
            const iconEl = document.createElement("span");
            iconEl.className = "promo-wrap__badge-icon";
            iconEl.setAttribute("aria-hidden", "true");
            node.appendChild(iconEl);
          }
        }

        // Generate safe anchor ID
        const anchor = safeSlug(normalizedTag);

        // Skip if we've already assigned this anchor or if it already exists in the DOM
        if (assignedAnchors.has(anchor)) {
          return;
        }

        // Check for collision with existing IDs (e.g., heading anchors)
        if (element.querySelector(`#${CSS.escape(anchor)}`)) {
          return;
        }

        // Assign the ID to this element
        node.id = anchor;
        assignedAnchors.add(anchor);
      });
    },
    { id: "promo-wrap-anchor" }
  );
});
