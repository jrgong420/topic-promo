# Topic Promo (Discourse Theme Component)

A small theme component that shows a “promo” button on topics matching configured tags. The button uses Discourse’s primary button style and jumps directly to the first post of the topic (`/t/slug/topicId/1`).

## Features
- Show promo button on topics with specific tags
- Primary button styling; works in light and dark schemes
- Mobile-friendly: icon-only on mobile, icon + text on desktop
- Configurable Font Awesome icon (default: `gift`)

## Settings
Configure these in the theme’s settings:

- `promo_trigger_tags` (list, tag)
  - Pipe-separated list of tags. When any of these tags are present on a topic, the promo button is shown.
- `promo_button_icon` (string, default: `gift`)
  - Enter a Font Awesome icon name without the `fa-` prefix.
  - Examples: `gift`, `chevron-up`, `arrow-up`, `star`.
- `promo_anchor_heading` (string, optional)
  - Reserved for future use to target a specific heading anchor in the first post.

## How it looks/works
- Desktop: The button shows the configured icon followed by the localized label.
- Mobile: The button shows only the icon for a compact look.
- Clicking the button navigates to the first post of the topic (`/t/slug/topicId/1`).

## Installation
1) Add/Install this theme component to your Discourse instance.
2) Open the component’s settings and configure:
   - `promo_trigger_tags` with your desired tags
   - `promo_button_icon` if you want a different icon (default is `gift`)
3) Visit a topic that has one of the configured tags and verify the button appears.

## Compatibility
- Discourse: minimum version `3.2.0` (see about.json)
- Uses modern Glimmer component patterns and is SPA-safe.

## License & Links
- See `LICENSE`
- Meta topic / Learn more: to be published (see `about.json`)
