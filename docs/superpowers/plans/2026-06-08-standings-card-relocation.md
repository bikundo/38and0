# Standings Card Relocation and WhatsApp Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the standings card (W-D-L results, first loss, and funny quote) from the left column to the right-column controller panel when the season is complete, rename restart buttons to "Play Again", and add a "Share to WhatsApp" option alongside "Share to Twitter" with instant client-side sharing.

**Architecture:** Replace the controller card entirely in `:game_over` and `:hall_of_fame` steps with the standings card. Use verified routes to generate absolute share URLs in the LiveView template and pass them via `data-share-url` to Twitter and WhatsApp share buttons. Inside `assets/js/app.js`, handle click events synchronously on the client side to bypass browser pop-up blockers.

**Tech Stack:** Elixir, Phoenix LiveView v1.8, JavaScript (ES6), Tailwind CSS

---

### Task 1: Fix tag mismatch in game_live.ex

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`

- [ ] **Step 1: Remove the extra closing `div` on line 921**
  Remove the stray `</div>` tag that closes `lg:col-span-8` early.

- [ ] **Step 2: Run mix test to verify compilation is fixed**
  Run: `mix test`
  Expected: Compilation passes (even if some assertions fail).

---

### Task 2: Implement Standings Card in the Controller Column

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`

- [ ] **Step 1: Update the right column template**
  Restructure lines 970 to 1581 of `game_live.ex` to check if step is in `:game_over` or `:hall_of_fame`. If it is NOT, render the current controller card with steps `:not_started`, `:spinning`, `:drafting`, `:squad_complete`, and `:simulating`.
  If it IS, render the standings card block and the desktop Match History card underneath it.

- [ ] **Step 2: Use "Play Again" button text**
  Ensure the restart button in the standings card is:
  ```html
  <button
    phx-click="start_game"
    class="w-full btn-starbucks btn-starbucks-filled text-sm py-3 font-bold uppercase tracking-wider"
  >
    Play Again
  </button>
  ```

- [ ] **Step 3: Setup Twitter and WhatsApp share buttons in the card footer**
  Embed the sharing grid inside the card footer:
  ```html
  <div class="bg-[#f7f7f5] border-t border-[rgba(0,0,0,0.08)] px-5 py-4 flex flex-col gap-3">
    <div class="flex items-center justify-between text-[10px] text-[rgba(0,0,0,0.5)] font-semibold uppercase tracking-[0.4px]">
      <span>GA: {@season_record.ga} · Pts: {pts}</span>
      <%= if @sim_results && Map.get(@sim_results, :season_label) do %>
        <span>Season: {@sim_results.season_label}</span>
      <% end %>
    </div>
    <div class="grid grid-cols-2 gap-2">
      <button
        id="share-twitter"
        phx-hook="ShareButton"
        data-wins={@season_record.wins}
        data-draws={@season_record.draws}
        data-losses={@season_record.losses}
        data-points={pts}
        data-season={if @sim_results, do: Map.get(@sim_results, :season_label, ""), else: ""}
        data-quote={funny_quote}
        data-share-url={share_url}
        class="btn-starbucks btn-starbucks-black text-[10px] sm:text-xs py-2 px-2.5 flex items-center justify-center gap-1.5 whitespace-nowrap shadow-sm font-bold tracking-wider"
      >
        <svg class="w-3.5 h-3.5 fill-current text-white" viewBox="0 0 24 24">
          <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
        </svg>
        SHARE TO TWITTER
      </button>
      <button
        id="share-whatsapp"
        phx-hook="WhatsAppShareButton"
        data-wins={@season_record.wins}
        data-draws={@season_record.draws}
        data-losses={@season_record.losses}
        data-points={pts}
        data-season={if @sim_results, do: Map.get(@sim_results, :season_label, ""), else: ""}
        data-quote={funny_quote}
        data-share-url={share_url}
        class="bg-[#25D366] hover:bg-[#20ba5a] text-white font-extrabold text-[10px] sm:text-xs py-2 px-2.5 rounded-[50px] transition-all flex items-center justify-center gap-1.5 whitespace-nowrap shadow-sm tracking-wider"
      >
        <svg class="w-3.5 h-3.5 fill-current text-white" viewBox="0 0 24 24">
          <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946C.06 5.348 5.397.01 12.008.01c3.202.001 6.212 1.246 8.477 3.514 2.266 2.268 3.507 5.28 3.505 8.484-.004 6.657-5.34 11.997-11.953 11.997-2.005-.001-3.973-.502-5.724-1.455L0 24zm6.59-4.846c1.6.95 3.488 1.459 5.407 1.461 5.432.003 9.85-4.413 9.854-9.847.002-2.63-1.023-5.101-2.887-6.969C17.159 1.932 14.686.907 12.06.907c-5.434 0-9.852 4.414-9.855 9.848-.002 1.81.472 3.58 1.375 5.143l-.975 3.565 3.65-.958zm10.742-5.403c-.3-.15-1.774-.875-2.046-.975-.272-.1-.471-.15-.669.15-.198.3-.765.976-.939 1.176-.173.199-.347.224-.648.075-1.037-.517-1.829-.916-2.543-1.52-.356-.302-.569-.646-.669-.896-.099-.25-.01-.385.088-.482.089-.088.199-.232.298-.348.099-.117.133-.199.199-.332.066-.133.033-.25-.017-.35-.05-.1-1.774-4.275-2.046-4.925-.265-.638-.535-.55-.669-.557l-.57-.008c-.198 0-.52.075-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.774-.725 2.022-1.424.248-.699.248-1.299.174-1.424-.075-.125-.272-.199-.57-.349z"/>
        </svg>
        SHARE TO WHATSAPP
      </button>
    </div>
  </div>
  ```

---

### Task 3: Implement Instant Twitter & WhatsApp Sharing in app.js

**Files:**
- Modify: `assets/js/app.js`

- [ ] **Step 1: Move text helper functions to top-level scope**
  Move `getTwitterLength` and `truncateToTwitterLength` from inside `ShareButton` to the top scope of `app.js` (above `const Hooks = {`).

- [ ] **Step 2: Update `ShareButton` in Hooks**
  Modify `ShareButton` to check `const directUrl = this.el.dataset.shareUrl`. If present, build the tweet text and immediately run `window.open(twitterUrl, "_blank")`. If not, fall back to pushing `"share_lineup"` to the server.

- [ ] **Step 3: Add `WhatsAppShareButton` to Hooks**
  Implement `WhatsAppShareButton` to read `data-share-url`, construct the WhatsApp message (quote, W-D-L stats, CTA link, `#InvinciblesDraft`), encode it, and call `window.open(whatsappUrl, "_blank")`.

---

### Task 4: Verification and Precommit

- [ ] **Step 1: Run mix test**
  Run: `mix test`
  Expected: All tests pass.

- [ ] **Step 2: Run precommit checks**
  Run: `mix precommit`
  Expected: All formatting, style, and linters pass cleanly.
