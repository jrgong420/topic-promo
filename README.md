# Topic Promo (Discourse Theme Component)

A Discourse theme component that shows a promotional button on topics with specific tags. The button links directly to promotional content within the first post using anchor links.

## Features
- Show promo button on topics with specific tags
- Automatically links to `[wrap=TAG]` BBCode content in the first post
- Primary button styling; works in light and dark schemes
- Mobile-friendly: icon-only on mobile, icon + text on desktop
- Configurable Font Awesome icon (default: `gift`)
- Smart anchor generation following Discourse heading anchor conventions
- Works even when user is viewing later posts (navigates to first post + anchor)

## Settings
Configure these in the theme's settings:

- `promo_trigger_tags` (list, tag)
  - Pipe-separated list of tags. When any of these tags are present on a topic, the promo button is shown.
  - The button will link to `[wrap=TAG]` content in the first post matching one of these tags.
  - Example: `featured|promo|deal`
- `promo_button_icon` (string, default: `gift`)
  - Enter a Font Awesome icon name without the `fa-` prefix.
  - Examples: `gift`, `chevron-up`, `arrow-up`, `star`.

## How it works

### 1. Tag-based button rendering
When a topic has one of the configured tags (e.g., `featured`), the promo button appears on both desktop and mobile.

### 2. Anchor link generation
The button links to the first post with an anchor targeting the matching tag:
- URL format: `/t/slug/topicId/1#tag`
- Example: `/t/my-topic/123/1#featured`
- This works even if the user is currently viewing post #50 or later

### 3. BBCode wrap detection
In the first post, use BBCode wrap syntax to mark promotional content:

\`\`\`
[wrap=featured]
## Special Offer!
This is your promotional content that users will scroll to.
[/wrap]
\`\`\`

Discourse renders this as:
\`\`\`html
<div class="d-wrap" data-wrap="featured" id="featured">
  <h2>Special Offer!</h2>
  <p>This is your promotional content that users will scroll to.</p>
</div>
\`\`\`

The theme component automatically adds the \`id="featured"\` attribute to enable anchor scrolling.

### 4. Anchor ID assignment
- Only the first post is processed
- Only \`.d-wrap\` elements with \`data-wrap\` matching a configured tag get IDs
- IDs are normalized to kebab-case (lowercase, dashes) following Discourse heading anchor conventions
- Collision detection: if a heading or other element already has the same ID, the wrap element is skipped
- Only the first occurrence of each tag gets an ID (avoids duplicate IDs)

## Example usage

**Settings:**
\`\`\`
promo_trigger_tags: featured|special-offer
promo_button_icon: gift
\`\`\`

**Topic tags:** \`featured\`, \`discussion\`

**First post content:**
\`\`\`
Welcome to this topic!

[wrap=featured]
## 🎁 Limited Time Offer
Get 50% off with code PROMO50!
[/wrap]

More content here...
\`\`\`

**Result:**
- Button appears with gift icon and "Scroll to promo" label
- Button links to \`/t/topic-slug/123/1#featured\`
- Clicking scrolls directly to the promotional content
- Works from any post in the topic

## Installation
1) Add/Install this theme component to your Discourse instance.
2) Open the component's settings and configure:
   - \`promo_trigger_tags\` with your desired tags (e.g., \`featured|promo\`)
   - \`promo_button_icon\` if you want a different icon (default is \`gift\`)
3) In your topic's first post, add BBCode wrap sections:
   \`\`\`
   [wrap=featured]
   Your promotional content here
   [/wrap]
   \`\`\`
4) Add the matching tag to your topic (e.g., \`featured\`)
5) Visit the topic and verify the button appears and scrolls to the content

## Technical details

### SPA-safe implementation
- Uses Discourse's modern Glimmer component patterns
- Clears per-view state on page navigation
- No redirect loops or memory leaks
- Event delegation for dynamic content

### Anchor link methodology
Follows Discourse core's heading anchor approach:
- Kebab-case normalization (lowercase, dashes)
- Collision detection with existing IDs
- Browser-native anchor scrolling
- Works across different posts in the same topic

### Performance
- Minimal DOM processing (scoped to first post only)
- No global MutationObservers
- Idempotent rendering
- Efficient tag matching

## Compatibility
- Discourse: minimum version \`3.2.0\` (see about.json)
- Uses modern Glimmer component patterns
- No deprecated widget APIs
- Mobile and desktop responsive

## Localization
The button label can be customized in \`locales/en.yml\`:
\`\`\`yaml
en:
  js:
    promo_button:
      label: "Scroll to promo"
\`\`\`

Add additional language files as needed (e.g., \`locales/fr.yml\`, \`locales/de.yml\`).

## License & Links
- See \`LICENSE\`
- Meta topic / Learn more: to be published (see \`about.json\`)
