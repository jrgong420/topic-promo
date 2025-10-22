import { apiInitializer } from "discourse/lib/api";
import PromoScrollButton from "../components/promo-scroll-button";

export default apiInitializer((api) => {
  // Desktop: place near timeline controls
  api.renderInOutlet(
    "timeline-controls-before",
    <template>
      <PromoScrollButton @topicModel={{@outletArgs.model}} @topicAlt={{@outletArgs.topic}} @isMobile={{false}} />
    </template>
  );

  // Mobile: place after topic progress (requested location)
  api.renderInOutlet(
    "after-topic-progress",
    <template>
      <PromoScrollButton @topicModel={{@outletArgs.model}} @topicAlt={{@outletArgs.topic}} @isMobile={{true}} />
    </template>
  );
});

