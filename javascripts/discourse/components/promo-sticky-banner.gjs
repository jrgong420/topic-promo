import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { getOwner } from "@ember/owner";
import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

export default class PromoStickyBanner extends Component {
  @service site;
  @service router;

  @tracked dismissed = false;

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
      !!this.anchorElement &&
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

  get ariaLabel() {
    return i18n(themePrefix("js.promo_banner.label"));
  }

  get dismissAriaLabel() {
    return i18n(themePrefix("js.promo_banner.dismiss"));
  }

  @action onClick(e) {
    if (!this.promoHref) return;
    // Ignore if clicking the dismiss button
    if (e?.target?.closest?.(".promo-banner__dismiss")) return;
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
    const key = this.cookieKey;
    if (key) {
      const days = Math.max(1, Math.min(365, Number(settings.sticky_banner_cookie_lifespan || 30)));
      this._setCookie(key, "1", days);
    }
    this.dismissed = true;
  }

  <template>
    {{#if this.shouldShow}}
      <div
        class="promo-banner"
        role="button"
        tabindex="0"
        aria-label={{this.ariaLabel}}
        {{on "click" this.onClick}}
        {{on "keydown" this.onKeydown}}
      >
        <div class="promo-banner__inner">
          <span class="promo-banner__icon">{{this.iconHtml}}</span>
          <span class="promo-banner__label">{{settings.sticky_banner_text}}</span>
          <button
            type="button"
            class="promo-banner__dismiss"
            aria-label={{this.dismissAriaLabel}}
            {{on "click" this.dismiss}}
          >
            ×
          </button>
        </div>
      </div>
    {{/if}}
  </template>
}

