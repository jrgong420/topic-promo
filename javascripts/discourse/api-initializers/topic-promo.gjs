import { apiInitializer } from "discourse/lib/api";

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
        // Expose the first post ID on the wrap for cookie key suffixing
        try { node.dataset.wrapId = String(post.id); } catch {}
        assignedAnchors.add(anchor);
      });
    },
    { id: "promo-wrap-anchor" }
  );
});
