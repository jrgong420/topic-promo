import { apiInitializer } from "discourse/lib/api";
import PromoStickyBanner from "../components/promo-sticky-banner";

// eslint-disable-next-line no-console
console.debug("[Topic Promo][Init] Registering sticky banner in 'after-header' outlet");

export default apiInitializer((api) => {
  // Render sticky banner directly below the site header
  api.renderInOutlet(
    "after-header",
    <template>
      <PromoStickyBanner @outletArgs={{@outletArgs}} />
    </template>
  );
});

