import { apiInitializer } from "discourse/lib/api";
import PromoStickyBanner from "../components/promo-sticky-banner";

export default apiInitializer((api) => {
  // Render sticky banner directly below the site header
  api.renderInOutlet(
    "after-header",
    <template>
      <PromoStickyBanner @outletArgs={{@outletArgs}} />
    </template>
  );
});

