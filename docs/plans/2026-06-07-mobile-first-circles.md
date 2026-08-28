# Mobile-First Layout and Circle Lineup Badges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the draft layout mobile-friendly and replace the rectangular player cards on the soccer pitch with circular badges that show abbreviations and names.

**Architecture:** Use responsive Tailwind order utilities on the layout grid columns, declare a static sub-label description map for positions, and render circular nodes for empty/occupied states.

**Tech Stack:** Elixir, Phoenix LiveView, Tailwind CSS.

---

### Task 1: Setup Helpers in GameLive

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`

- [ ] **Step 1: Add `@position_descriptions` and `truncate_name/1` helper**
  Add the following code to the module:
  ```elixir
  @position_descriptions %{
    gk: "Goalkeeper",
    lb: "Left",
    cb1: "Centre",
    cb2: "Centre",
    cb3: "Centre",
    rb: "Right",
    lm: "Left",
    cm: "Attacking",
    cm1: "Defensive",
    cm2: "Defensive",
    cm3: "Centre",
    rm: "Right",
    lw: "Left",
    rw: "Right",
    st: "Striker",
    st1: "Striker",
    st2: "Striker"
  }

  defp truncate_name(name) do
    last_name =
      case String.split(name, " ") do
        [single] -> single
        parts -> List.last(parts)
      end

    if String.length(last_name) > 7 do
      String.slice(last_name, 0, 6) <> "..."
    else
      last_name
    end
  end
  ```

- [ ] **Step 2: Verify compilation**
  Run: `mix compile`
  Expected: Successful compilation without warnings.

- [ ] **Step 3: Commit**
  Run: `git commit -am "feat: add position descriptions and name truncation helper"`

---

### Task 2: Implement Circle Lineup Badges on soccer pitch

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`

- [ ] **Step 1: Replace Attacking line template**
  Replace the Attacking Line markup (lines ~333-363) with:
  ```html
  <!-- Attacking Line -->
  <div class="flex justify-around items-center gap-2 z-10 mt-2">
    <%= for pos <- layout.fwd do %>
      <div
        data-position-key={pos}
        class="pitch-slot flex flex-col items-center justify-center transition-all duration-200 cursor-pointer"
      >
        <%= if card = @lineup[pos] do %>
          <!-- Occupied Circle -->
          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg cursor-grab active:cursor-grabbing hover:scale-105 transition-all">
            {@position_names[pos]}
          </div>
          <div class="mt-2 px-3 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold max-w-[80px] sm:max-w-[100px] truncate shadow">
            {truncate_name(card.player.display_name)}
          </div>
        <% else %>
          <!-- Empty Circle -->
          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
            {@position_names[pos]}
          </div>
          <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
            {@position_descriptions[pos]}
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
  ```

- [ ] **Step 2: Replace Midfield line template**
  Replace the Midfield Line markup (lines ~368-399) with:
  ```html
  <!-- Midfield Line -->
  <div class="flex justify-around items-center gap-2 z-10 my-4">
    <%= for pos <- layout.mid do %>
      <div
        data-position-key={pos}
        class="pitch-slot flex flex-col items-center justify-center transition-all duration-200 cursor-pointer"
      >
        <%= if card = @lineup[pos] do %>
          <!-- Occupied Circle -->
          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg cursor-grab active:cursor-grabbing hover:scale-105 transition-all">
            {@position_names[pos]}
          </div>
          <div class="mt-2 px-3 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold max-w-[80px] sm:max-w-[100px] truncate shadow">
            {truncate_name(card.player.display_name)}
          </div>
        <% else %>
          <!-- Empty Circle -->
          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
            {@position_names[pos]}
          </div>
          <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
            {@position_descriptions[pos]}
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
  ```

- [ ] **Step 3: Replace Defensive line template**
  Replace the Defensive Line markup (lines ~403-434) with:
  ```html
  <!-- Defensive Line -->
  <div class="flex justify-around items-center gap-2 z-10">
    <%= for pos <- layout.def do %>
      <div
        data-position-key={pos}
        class="pitch-slot flex flex-col items-center justify-center transition-all duration-200 cursor-pointer"
      >
        <%= if card = @lineup[pos] do %>
          <!-- Occupied Circle -->
          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg cursor-grab active:cursor-grabbing hover:scale-105 transition-all">
            {@position_names[pos]}
          </div>
          <div class="mt-2 px-3 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold max-w-[80px] sm:max-w-[100px] truncate shadow">
            {truncate_name(card.player.display_name)}
          </div>
        <% else %>
          <!-- Empty Circle -->
          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
            {@position_names[pos]}
          </div>
          <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
            {@position_descriptions[pos]}
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
  ```

- [ ] **Step 4: Replace Goalkeeper template**
  Replace Goalkeeper markup (lines ~437-460) with:
  ```html
  <!-- Goalkeeper (GK) -->
  <div class="flex justify-center items-center z-10 mb-2">
    <div
      data-position-key="gk"
      class="pitch-slot flex flex-col items-center justify-center transition-all duration-200 cursor-pointer"
    >
      <%= if card = @lineup[:gk] do %>
        <!-- Occupied Circle -->
        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg cursor-grab active:cursor-grabbing hover:scale-105 transition-all">
          {@position_names[:gk]}
        </div>
        <div class="mt-2 px-3 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold max-w-[80px] sm:max-w-[100px] truncate shadow">
          {truncate_name(card.player.display_name)}
        </div>
      <% else %>
        <!-- Empty Circle -->
        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
          {@position_names[:gk]}
        </div>
        <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
          {@position_descriptions[:gk]}
        </div>
      <% end %>
    </div>
  </div>
  ```

- [ ] **Step 5: Verify compilation and tests**
  Run: `mix test`
  Expected: PASS

- [ ] **Step 6: Commit**
  Run: `git commit -am "feat: replace rectangular player cards with responsive lineup circles"`

---

### Task 3: Adjust Layout Container for Mobile-First Stack Ordering

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`

- [ ] **Step 1: Re-order columns inside `<main>` container**
  Change the column blocks inside the main grid container:
  * Find the Soccer Pitch column block (lines ~307-528) and update its class to include `order-2 lg:order-1 lg:col-span-8`.
  * Find the Game Controllers/Draft Pool column block (lines ~529-800+) and update its class to include `order-1 lg:order-2 lg:col-span-4`.

- [ ] **Step 2: Verify compilation and tests**
  Run: `mix test`
  Expected: PASS

- [ ] **Step 3: Commit**
  Run: `git commit -am "feat: implement mobile-first stacking layout with interactive controls on top"`
