import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { getOwner } from "@ember/owner";
import { htmlSafe } from "@ember/template";
import { on } from "@ember/modifier";
import { schedule } from "@ember/runloop";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

export default class PromoStickyBanner extends Component {
  @service site;
  @service router;

  @tracked dismissed = false;
  @tracked anchorFound = false;
  @tracked scrolledPastFirstPost = false;
  _anchorPollId = null;
  _intersectionObserver = null;

  _log(...args) {
    try {
      // eslint-disable-next-line no-console
      console.debug("[Topic Promo][StickyBanner]", ...args);
    } catch {}
  }

  _stateSummary(label = "state") {
    const topic = this.currentTopic;
    const summary = {
      label,
      route: this.router?.currentRouteName,
      topicId: topic?.id,
      topicSlug: topic?.slug,
      matchedTag: this.matchedTag,
      anchorId: this.anchorId,
      anchorFound: this.anchorFound,
      hasAnchorEl: !!this.anchorElement,
      scrolledPastFirstPost: this.scrolledPastFirstPost,
      cookieKey: this.cookieKey,
      cookieVal: this.cookieKey ? this._readCookie(this.cookieKey) : null,
      deviceAllowed: this.deviceAllowed,
      isMobile: !!this.site?.mobileView,
      dismissed: this.dismissed,
      shouldShow: this.shouldShow,
      href: this.promoHref,
    };
    this._log("state", summary);
  }

  constructor() {
    super(...arguments);
    this._log("constructor init", { outletArgs: Object.keys(this.args?.outletArgs || {}) });
    this._routeDidChange = () => {
      this._log("routeDidChange");
      // Reset per-view state when navigating between routes/topics
      this.dismissed = false;
      this.anchorFound = false;
      this._teardownScrollObserver();
      this._initScrollStateFromURL();
      if (!this._anchorPollId) {
        this._startAnchorPoll();
      }
      // Setup scroll observer after render
      schedule("afterRender", () => {
        this._setupScrollObserver();
      });
      this._stateSummary("routeDidChange-reset");
    };
    try {
      this.router?.on?.("routeDidChange", this._routeDidChange);
    } catch {}
    this._initScrollStateFromURL();
    this._startAnchorPoll();
    // Setup scroll observer after initial render
    schedule("afterRender", () => {
      this._setupScrollObserver();
    });
    this._stateSummary("constructor");
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._anchorPollId) {
      clearInterval(this._anchorPollId);
      this._anchorPollId = null;
    }
    this._teardownScrollObserver();
    try {
      this.router?.off?.("routeDidChange", this._routeDidChange);
    } catch {}
  }

  get currentTopic() {
    const argTopic = (
      this.args?.topic ||
      this.args?.topicModel ||
      this.args?.topicAlt ||
      this.args?.model ||
      this.args?.outletArgs?.model ||
      this.args?.outletArgs?.topic
    );
    if (argTopic) return argTopic;
    try {
      const controller = getOwner(this)?.lookup?.("controller:topic");
      return controller?.model;
    } catch {
      return null;
    }
  }

  get topicTags() {
    return this.currentTopic?.tags || [];
  }

  get configuredTags() {
    const raw = (settings.promo_trigger_tags || "").split("|");
    return raw.map((t) => t.trim()).filter(Boolean);
  }

  // Normalize tag to a safe HTML id (kebab-case, lowercase)
  safeSlug(str) {
    return (str || "")
      .toLowerCase()
      .trim()
      .replace(/[\s_]+/g, "-")
      .replace(/[^a-z0-9-]/g, "");
  }

  // Find first configured tag that exists on the topic
  get matchedTag() {
    if (!this.configuredTags.length || !this.topicTags.length) return null;
    const normalizedTopicTags = this.topicTags.map((t) => t.toLowerCase());
    const normalizedConfigTags = this.configuredTags.map((t) => t.toLowerCase());
    return normalizedConfigTags.find((configTag) =>
      normalizedTopicTags.includes(configTag)
    );
  }

  get anchorId() {
    return this.matchedTag ? this.safeSlug(this.matchedTag) : null;
  }

  get promoHref() {
    const topic = this.currentTopic;
    if (!topic) return null;
    const base = (topic.url || `/t/${topic.slug}/${topic.id}` || "").replace(/\/+$/, "");
    if (!base) return null;
    if (this.anchorId) {
      return `${base}/1#${this.anchorId}`;
    }
    return `${base}/1`;
  }

  // Try to find the anchor element in the DOM (first post)
  get anchorElement() {
    if (!this.anchorId) return null;
    try {
      return document.getElementById(this.anchorId);
    } catch {
      return null;
    }
  }

  _updateAnchorFound() {
    this.anchorFound = !!this.anchorElement;
  }

  _startAnchorPoll() {
    // Poll for a short period to allow first post render + decorateCooked
    let attempts = 0;
    const maxAttempts = 50; // ~15s at 300ms
    this._log("anchor poll start", { anchorId: this.anchorId, maxAttempts });
    this._anchorPollId = setInterval(() => {
      attempts++;
      const wasFound = this.anchorFound;
      this._updateAnchorFound();
      this._log("anchor poll attempt", attempts, { anchorId: this.anchorId, found: this.anchorFound });
      if (!wasFound && this.anchorFound) {
        this._log("anchor found", { anchorId: this.anchorId, hasAnchorEl: !!this.anchorElement });
        this._stateSummary("anchor-found");
      }
      if (this.anchorFound || attempts >= maxAttempts) {
        clearInterval(this._anchorPollId);
        this._anchorPollId = null;
        this._log("anchor poll end", { attempts, found: this.anchorFound });
        // Setup scroll observer once anchor is found or polling ends
        schedule("afterRender", () => {
          this._setupScrollObserver();
        });
      }
    }, 300);
  }

  // Get header offset for scroll calculations
  _getHeaderOffset() {
    try {
      const cssVar = getComputedStyle(document.documentElement)
        .getPropertyValue("--header-offset");
      const parsed = parseInt(cssVar || "60", 10);
      return Math.max(0, parsed || 60);
    } catch {
      return 60; // Fallback
    }
  }

  // Initialize scroll state from URL (for deep links to post > 1)
  _initScrollStateFromURL() {
    try {
      const match = window.location.pathname.match(/\/t\/[^/]+\/\d+\/(\d+)/);
      if (match) {
        const postNumber = parseInt(match[1], 10);
        this.scrolledPastFirstPost = postNumber > 1;
        this._log("init scroll state from URL", { postNumber, scrolledPast: this.scrolledPastFirstPost });
      } else {
        this.scrolledPastFirstPost = false;
      }
    } catch {
      this.scrolledPastFirstPost = false;
    }
  }

  // Setup IntersectionObserver to detect when user scrolls past first post
  _setupScrollObserver() {
    // Clean up any existing observer first
    this._teardownScrollObserver();

    const sentinel = document.querySelector(".promo-first-post-sentinel");
    if (!sentinel) {
      this._log("scroll observer: sentinel not found");
      return;
    }

    try {
      const headerOffset = this._getHeaderOffset();
      const rootMargin = `-${headerOffset}px 0px 0px 0px`;

      this._intersectionObserver = new IntersectionObserver(
        ([entry]) => {
          // When sentinel is NOT intersecting (not visible), user has scrolled past it
          const pastFirstPost = !entry.isIntersecting;
          if (this.scrolledPastFirstPost !== pastFirstPost) {
            this.scrolledPastFirstPost = pastFirstPost;
            this._log("scroll state changed", {
              scrolledPast: pastFirstPost,
              isIntersecting: entry.isIntersecting
            });
            this._stateSummary("scroll-changed");
          }
        },
        {
          root: null, // viewport
          rootMargin,
          threshold: 0,
        }
      );

      this._intersectionObserver.observe(sentinel);
      this._log("scroll observer setup", { headerOffset, rootMargin });
    } catch (error) {
      this._log("scroll observer setup failed", error);
    }
  }

  // Teardown IntersectionObserver
  _teardownScrollObserver() {
    if (this._intersectionObserver) {
      this._intersectionObserver.disconnect();
      this._intersectionObserver = null;
      this._log("scroll observer teardown");
    }
  }

  // Post ID to suffix cookie name (set by topic-promo initializer as data-wrap-id)
  get firstPostIdForCookie() {
    return this.anchorElement?.dataset?.wrapId || null;
  }

  // Cookie helpers (simple, theme-scoped)
  _readCookie(name) {
    if (!name) return null;
    const parts = document.cookie.split("; ");
    for (const part of parts) {
      const [k, ...rest] = part.split("=");
      if (k === decodeURIComponent(name)) {
        return decodeURIComponent(rest.join("="));
      }
    }
    return null;
  }

  _setCookie(name, value, days) {
    if (!name) return;
    const date = new Date();
    date.setTime(date.getTime() + days * 24 * 60 * 60 * 1000);
    const expires = `expires=${date.toUTCString()}`;
    const path = "path=/";
    document.cookie = `${encodeURIComponent(name)}=${encodeURIComponent(value)}; ${expires}; ${path}`;
  }

  get cookieKey() {
    const base = (settings.sticky_banner_cookie_name || "sticky_banner_dismissed_post").trim();
    if (!base) return null;
    if (this.firstPostIdForCookie) {
      return `${base}_${this.firstPostIdForCookie}`;
    }
    // Fall back to base (rare case if data-wrap-id isn't available yet)
    return base;
  }

  get isDismissedByCookie() {
    // If cookie lifespan is 0, never persist dismissal (banner appears every time)
    const lifespan = Number(settings.sticky_banner_cookie_lifespan || 30);
    if (lifespan === 0) {
      return false;
    }
    const key = this.cookieKey;
    if (!key) return false;
    return this._readCookie(key) === "1";
  }

  get deviceAllowed() {
    const isMobile = !!this.site?.mobileView;
    return isMobile ? settings.display_sticky_banner_mobile : settings.display_sticky_banner_desktop;
  }

  get shouldShow() {
    return (
      !!this.currentTopic &&
      this.deviceAllowed &&
      !!this.matchedTag &&
      this.anchorFound &&
      this.scrolledPastFirstPost &&
      !this.isDismissedByCookie &&
      !this.dismissed
    );
  }

  get iconHtml() {
    const name = (settings.promo_button_icon || "gift").trim() || "gift";
    try {
      return htmlSafe(iconHTML(name));
    } catch {
      return htmlSafe(iconHTML("gift"));
    }
  }


  @action onClick(e) {
    if (!this.promoHref) return;
    // Ignore if clicking the dismiss button
    if (e?.target?.closest?.(".promo-banner__dismiss")) return;
    this._log("click banner", { href: this.promoHref });
    window.location.assign(this.promoHref);
  }

  @action onKeydown(e) {
    if (!e) return;
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      this.onClick(e);
    }
  }

  @action dismiss(e) {
    e?.stopPropagation?.();
    const lifespan = Number(settings.sticky_banner_cookie_lifespan || 30);

    // Only set cookie if lifespan > 0 (lifespan = 0 means no persistence)
    if (lifespan > 0) {
      const key = this.cookieKey;
      if (key) {
        const days = Math.max(1, Math.min(365, lifespan));
        this._log("dismiss banner", { cookieKey: key, days });
        this._setCookie(key, "1", days);
      }
    } else {
      this._log("dismiss banner (no cookie, lifespan=0)");
    }

    this.dismissed = true;
    this._stateSummary("dismissed");
  }

  <template>
    {{#if this.shouldShow}}
      <div
        class="promo-banner"
        role="button"
        tabindex="0"
        aria-label={{i18n (themePrefix "js.promo_banner.label")}}
        {{on "click" this.onClick}}
        {{on "keydown" this.onKeydown}}
      >
        <div class="promo-banner__inner">
          <span class="promo-banner__icon">{{this.iconHtml}}</span>
          <span class="promo-banner__label">{{settings.sticky_banner_text}}</span>
          <button
            type="button"
            class="promo-banner__dismiss"
            aria-label={{i18n (themePrefix "js.promo_banner.dismiss")}}
            {{on "click" this.dismiss}}
          >
            ×
          </button>
        </div>
      </div>
    {{/if}}
  </template>
}

