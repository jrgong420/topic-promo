import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";



export default class PromoScrollButton extends Component {
  @tracked disabled = false;

  get currentTopic() {
    const argTopic = (
      this.args?.topic ||
      this.args?.topicModel ||
      this.args?.topicAlt ||
      this.args?.model ||
      this.args?.outletArgs?.model ||
      this.args?.outletArgs?.topic
    );

    if (argTopic) {
      return argTopic;
    }

    // Fallback: resolve topic from controller via owner lookup (SPA-safe)
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

  get shouldShow() {
    if (!this.configuredTags.length || !this.topicTags.length) {
      return false;
    }
    // Show if any configured tag is present on the topic
    return this.topicTags.some((t) => this.configuredTags.includes(t));
  }

  get showLabel() {
    return !this.args?.isMobile;
  }

  get iconName() {
    return (settings.promo_button_icon || "gift").trim() || "gift";
  }

  get iconHtml() {
    try {
      return htmlSafe(iconHTML(this.iconName));
    } catch {
      // Fallback to gift if icon library throws for unknown icon
      return htmlSafe(iconHTML("gift"));
    }
  }

  get promoHref() {
    // Navigate to the canonical first-post URL: /t/:slug/:topicId/1
    const topic = this.currentTopic;
    if (!topic) {
      return null;
    }

    // Prefer topic.url when available; it is typically "/t/:slug/:id"
    const base = (topic.url || `/t/${topic.slug}/${topic.id}` || "").replace(/\/+$/, "");
    if (!base) {
      return null;
    }

    return `${base}/1`;
  }



  <template>
    {{#if this.shouldShow}}
      <a
        class={{if @isMobile "btn btn-primary promo-button promo-button--icon-only" "btn btn-primary promo-button"}}
        href={{this.promoHref}}
        title={{i18n (themePrefix "js.promo_button.label")}}
        aria-label={{i18n (themePrefix "js.promo_button.label")}}
      >
        {{this.iconHtml}}
        {{#if this.showLabel}}
          {{i18n (themePrefix "js.promo_button.label")}}
        {{/if}}
      </a>
    {{/if}}
  </template>
}

