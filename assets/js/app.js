// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/invincibles"
import html2canvas from "html2canvas"
import topbar from "../vendor/topbar"

// A robust helper to convert oklch(...) to rgb(...)
function oklchToRgb(oklchStr) {
  const match = oklchStr.match(/oklch\(([\d%.]+)\s+([\d%.]+)\s+([\d%.]+)(?:\s*\/\s*([\d%.]+))?\)/) ||
                oklchStr.match(/oklch\(([\d%.]+),\s*([\d%.]+),\s*([\d%.]+)(?:,\s*([\d%.]+))?\)/);
  if (!match) return oklchStr;

  let l = parseFloat(match[1]);
  let c = parseFloat(match[2]);
  let h = parseFloat(match[3]);
  let a = match[4] !== undefined ? parseFloat(match[4]) : 1;

  if (match[1].includes('%')) l /= 100;
  if (match[2].includes('%')) c /= 100;

  const hRad = (h * Math.PI) / 180;
  const a_lab = c * Math.cos(hRad);
  const b_lab = c * Math.sin(hRad);

  const l_lms = l + 0.3963377774 * a_lab + 0.2158037573 * b_lab;
  const m_lms = l - 0.1055613458 * a_lab - 0.0638541728 * b_lab;
  const s_lms = l - 0.0894841775 * a_lab - 1.2914855480 * b_lab;

  const l3 = l_lms * l_lms * l_lms;
  const m3 = m_lms * m_lms * m_lms;
  const s3 = s_lms * s_lms * s_lms;

  const r_linear = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
  const g_linear = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
  const b_linear = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;

  const toSRGB = (c_lin) => {
    const clamped = Math.max(0, Math.min(1, c_lin));
    return clamped <= 0.0031308
      ? 12.92 * clamped
      : 1.055 * Math.pow(clamped, 1 / 2.4) - 0.055;
  };

  const r = Math.round(toSRGB(r_linear) * 255);
  const g = Math.round(toSRGB(g_linear) * 255);
  const b = Math.round(toSRGB(b_linear) * 255);

  if (a < 1) {
    return `rgba(${r}, ${g}, ${b}, ${a})`;
  }
  return `rgb(${r}, ${g}, ${b})`;
}

// A robust helper to convert oklab(...) to rgb(...)
function oklabToRgb(oklabStr) {
  const match = oklabStr.match(/oklab\(([\d%.]+)\s+([\d%.]+)\s+([\d%.]+)(?:\s*\/\s*([\d%.]+))?\)/) ||
                oklabStr.match(/oklab\(([\d%.]+),\s*([\d%.]+),\s*([\d%.]+)(?:,\s*([\d%.]+))?\)/);
  if (!match) return oklabStr;

  let l = parseFloat(match[1]);
  let a_lab = parseFloat(match[2]);
  let b_lab = parseFloat(match[3]);
  let a = match[4] !== undefined ? parseFloat(match[4]) : 1;

  if (match[1].includes('%')) l /= 100;
  if (match[2].includes('%')) a_lab /= 100;
  if (match[3].includes('%')) b_lab /= 100;

  const l_lms = l + 0.3963377774 * a_lab + 0.2158037573 * b_lab;
  const m_lms = l - 0.1055613458 * a_lab - 0.0638541728 * b_lab;
  const s_lms = l - 0.0894841775 * a_lab - 1.2914855480 * b_lab;

  const l3 = l_lms * l_lms * l_lms;
  const m3 = m_lms * m_lms * m_lms;
  const s3 = s_lms * s_lms * s_lms;

  const r_linear = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
  const g_linear = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
  const b_linear = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;

  const toSRGB = (c_lin) => {
    const clamped = Math.max(0, Math.min(1, c_lin));
    return clamped <= 0.0031308
      ? 12.92 * clamped
      : 1.055 * Math.pow(clamped, 1 / 2.4) - 0.055;
  };

  const r = Math.round(toSRGB(r_linear) * 255);
  const g = Math.round(toSRGB(g_linear) * 255);
  const b = Math.round(toSRGB(b_linear) * 255);

  if (a < 1) {
    return `rgba(${r}, ${g}, ${b}, ${a})`;
  }
  return `rgb(${r}, ${g}, ${b})`;
}

const Hooks = {
  SpinWheel: {
    mounted() {
      // ─── Decorative scroll items (the reel spins through these) ──────────
      // The LANDING item is always updated with the real DB result before
      // the reel decelerates to it — so the user sees the actual club+season.
      const CLUBS = [
        "Arsenal FC", "Chelsea FC", "Man United", "Liverpool FC", "Man City",
        "Tottenham", "Everton FC", "Newcastle Utd", "Aston Villa", "Leeds United",
        "Blackburn Rvrs", "Leicester City", "West Ham Utd", "Southampton", "Fulham FC",
        "Wolves", "Norwich City", "Ipswich Town", "Derby County", "Coventry City",
      ];
      const SEASONS = [
        "1992–93", "1993–94", "1994–95", "1995–96", "1996–97",
        "1997–98", "1998–99", "1999–00", "2000–01", "2001–02",
        "2002–03", "2003–04", "2004–05", "2005–06", "2006–07",
        "2007–08", "2008–09", "2009–10", "2010–11", "2011–12",
        "2012–13", "2013–14", "2014–15", "2015–16", "2016–17",
        "2017–18", "2018–19",
      ];

      const ITEM_H = 56;
      const VISIBLE = 5;
      const REEL_H = ITEM_H * VISIBLE;
      const CENTER_OFFSET = Math.floor(VISIBLE / 2); // = 2
      const FAST_MS = 1000;   // phase 1: constant fast scroll
      const DECEL_MS = 1600;  // phase 2: easeOutQuint deceleration
      const TOTAL_MS = FAST_MS + DECEL_MS;
      const FAST_SPEED = 1.8; // px/ms
      const fastDistance = FAST_MS * FAST_SPEED; // = 1800px

      const easeOutQuint = t => 1 - Math.pow(1 - t, 5);

      // ─── Shared spin state ────────────────────────────────────────────────
      // Set when animation starts, read in spin_result_ready handler
      let spinState = null;

      // ─── Build a reel ─────────────────────────────────────────────────────
      const buildReel = (items, label) => {
        // Build pool: enough repetitions for a satisfying spin
        const pool = [];
        for (let i = 0; i < 6; i++) pool.push(...items);

        // landingIdx: the item that will be centered when the reel stops.
        // We keep a DOM reference so we can swap its text before it comes
        // into view during Phase 2.
        const landingIdx = pool.length - CENTER_OFFSET - 1;

        const col = document.createElement("div");
        col.style.cssText = "flex: 1; display: flex; flex-direction: column; gap: 6px;";

        const lbl = document.createElement("div");
        lbl.style.cssText = "text-align: center; font-size: 10px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; color: rgba(0,0,0,0.35); margin-bottom: 4px;";
        lbl.textContent = label;

        const win = document.createElement("div");
        win.style.cssText = `position: relative; height: ${REEL_H}px; overflow: hidden; border-radius: 14px; border: 1.5px solid rgba(0,0,0,0.08); background: #f9f9f9;`;

        const maskTop = document.createElement("div");
        maskTop.style.cssText = `position: absolute; top: 0; left: 0; right: 0; height: ${ITEM_H * 1.5}px; background: linear-gradient(to bottom, rgba(249,249,249,1) 0%, transparent 100%); z-index: 3; pointer-events: none; border-radius: 14px 14px 0 0;`;
        const maskBot = document.createElement("div");
        maskBot.style.cssText = `position: absolute; bottom: 0; left: 0; right: 0; height: ${ITEM_H * 1.5}px; background: linear-gradient(to top, rgba(249,249,249,1) 0%, transparent 100%); z-index: 3; pointer-events: none; border-radius: 0 0 14px 14px;`;

        const highlight = document.createElement("div");
        highlight.style.cssText = `position: absolute; top: ${ITEM_H * CENTER_OFFSET}px; left: 6px; right: 6px; height: ${ITEM_H}px; border: 2px solid rgba(0,117,74,0.25); background: rgba(0,117,74,0.04); border-radius: 10px; z-index: 2; pointer-events: none; transition: border-color 300ms ease, background 300ms ease;`;

        const list = document.createElement("div");
        list.style.cssText = "will-change: transform; transform: translateY(0);";

        let landingEl = null;
        pool.forEach((item, i) => {
          const el = document.createElement("div");
          el.style.cssText = `height: ${ITEM_H}px; display: flex; align-items: center; justify-content: center; font-family: var(--font-sans, Inter, sans-serif); font-size: 13px; font-weight: 700; color: rgba(0,0,0,0.75); letter-spacing: -0.01em; padding: 0 8px; text-align: center;`;
          el.textContent = item;
          if (i === landingIdx) landingEl = el;
          list.appendChild(el);
        });

        win.appendChild(maskTop);
        win.appendChild(maskBot);
        win.appendChild(highlight);
        win.appendChild(list);
        col.appendChild(lbl);
        col.appendChild(win);

        // scrollTarget: how far translateY needs to go so landingIdx is centered
        const scrollTarget = (landingIdx - CENTER_OFFSET) * ITEM_H;
        const decelDist = Math.max(0, scrollTarget - fastDistance);

        return { col, list, highlight, landingEl, scrollTarget, decelDist };
      };

      // ─── Show the slot machine overlay ────────────────────────────────────
      const showSlotMachine = () => {
        const overlay = document.createElement("div");
        overlay.id = "slot-machine-overlay";
        overlay.style.cssText = "position: fixed; inset: 0; z-index: 9999; display: flex; align-items: center; justify-content: center; background: rgba(0,0,0,0.55); backdrop-filter: blur(6px); opacity: 0; transition: opacity 220ms cubic-bezier(0.16,1,0.3,1);";

        const card = document.createElement("div");
        card.style.cssText = "background: #fff; border-radius: 22px; padding: 28px 24px 32px; width: min(360px,92vw); box-shadow: 0 32px 80px rgba(0,0,0,0.35); transform: scale(0.94) translateY(12px); transition: transform 280ms cubic-bezier(0.16,1,0.3,1);";

        const heading = document.createElement("div");
        heading.style.cssText = "text-align: center; font-size: 11px; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase; color: rgba(0,0,0,0.35); margin-bottom: 22px;";
        heading.textContent = "Drawing Club & Season";

        const reelsRow = document.createElement("div");
        reelsRow.style.cssText = "display: flex; gap: 12px;";

        const clubReel = buildReel(CLUBS, "Club");
        const seasonReel = buildReel(SEASONS, "Season");
        reelsRow.appendChild(clubReel.col);
        reelsRow.appendChild(seasonReel.col);

        card.appendChild(heading);
        card.appendChild(reelsRow);
        overlay.appendChild(card);
        document.body.appendChild(overlay);

        // Fade in
        requestAnimationFrame(() => requestAnimationFrame(() => {
          overlay.style.opacity = "1";
          card.style.transform = "scale(1) translateY(0)";
        }));

        // ─── Two-phase reel animation ─────────────────────────────────────
        const spinStart = performance.now();
        let animResolved = false;

        const animate = (ts) => {
          const elapsed = ts - spinStart;
          let clubY, seasonY;

          if (elapsed <= FAST_MS) {
            // Phase 1: constant speed
            clubY = (elapsed / FAST_MS) * fastDistance;
            seasonY = clubY;
          } else {
            // Phase 2: easeOutQuint deceleration
            const t = Math.min((elapsed - FAST_MS) / DECEL_MS, 1);
            const eased = easeOutQuint(t);
            clubY = fastDistance + eased * clubReel.decelDist;
            seasonY = fastDistance + eased * seasonReel.decelDist;

            if (t >= 1 && !animResolved) {
              animResolved = true;
              // Flash highlights green — reel has locked in
              clubReel.highlight.style.borderColor = "rgba(0,117,74,0.7)";
              clubReel.highlight.style.background = "rgba(0,117,74,0.07)";
              seasonReel.highlight.style.borderColor = "rgba(0,117,74,0.7)";
              seasonReel.highlight.style.background = "rgba(0,117,74,0.07)";
            }
          }

          clubReel.list.style.transform = `translateY(-${clubY}px)`;
          seasonReel.list.style.transform = `translateY(-${seasonY}px)`;

          if (elapsed < TOTAL_MS) requestAnimationFrame(animate);
        };

        requestAnimationFrame(animate);

        return { overlay, clubReel, seasonReel, spinStart };
      };

      // ─── Shared spin trigger ──────────────────────────────────────────────
      const triggerSpin = () => {
        if (this.el.dataset.spinning === "true") return;
        this.el.dataset.spinning = "true";

        spinState = showSlotMachine();

        // Push to LiveView early so the result arrives during Phase 1,
        // giving us time to update the landing element before it scrolls in
        setTimeout(() => this.pushEvent("spin_wheel", {}), 800);

        setTimeout(() => { this.el.dataset.spinning = "false"; }, TOTAL_MS + 100);
      };

      this.el.addEventListener("click", triggerSpin);

      this.handleEvent("auto_spin", () => setTimeout(triggerSpin, 50));

      // ─── Receive real result, update the landing items, then dismiss ───────
      this.handleEvent("spin_result_ready", ({ club, season }) => {
        if (!spinState) return;
        const { overlay, clubReel, seasonReel, spinStart } = spinState;

        // Swap the landing element text to the real DB result.
        // This item is still scrolled offscreen at this point (early in Phase 2),
        // so the user never sees the swap — they just see the correct name stop in center.
        if (clubReel.landingEl) clubReel.landingEl.textContent = club;
        if (seasonReel.landingEl) seasonReel.landingEl.textContent = season;

        // Calculate remaining animation time and add 1s linger after it stops
        const elapsed = performance.now() - spinStart;
        const msLeft = Math.max(0, TOTAL_MS - elapsed);

        setTimeout(() => {
          if (!overlay) return;
          overlay.style.opacity = "0";
          overlay.style.transition = "opacity 300ms cubic-bezier(0.16,1,0.3,1)";
          setTimeout(() => {
            overlay.remove();
            spinState = null;
            this.pushEvent("animation_done", {});
          }, 320);
        }, msLeft + 1000); // wait for reel to stop + 1s
      });
    }
  },

  ShareButton: {
    mounted() {
      this.el.addEventListener("click", () => {
        const pitchEl = document.getElementById("game-pitch-container");
        if (!pitchEl) return;

        // Intercept getComputedStyle to bypass oklch/oklab failures in html2canvas
        const originalGetComputedStyle = window.getComputedStyle;
         const oklchToRgbLocal = (oklchStr) => {
          const match = oklchStr.match(/oklch\(([-.\d%.]+)\s+([-.\d%.]+)\s+([-.\d%.]+)(?:\s*\/\s*([-.\d%.]+))?\)/) ||
                        oklchStr.match(/oklch\(([-.\d%.]+),\s*([-.\d%.]+),\s*([-.\d%.]+)(?:,\s*([-.\d%.]+))?\)/);
          if (!match) return oklchStr;
          let l = parseFloat(match[1]);
          let c = parseFloat(match[2]);
          let h = parseFloat(match[3]);
          let a = match[4] !== undefined ? parseFloat(match[4]) : 1;
          if (match[1].includes('%')) l /= 100;
          if (match[2].includes('%')) c /= 100;
          const hRad = (h * Math.PI) / 180;
          const a_lab = c * Math.cos(hRad);
          const b_lab = c * Math.sin(hRad);
          const l_lms = l + 0.3963377774 * a_lab + 0.2158037573 * b_lab;
          const m_lms = l - 0.1055613458 * a_lab - 0.0638541728 * b_lab;
          const s_lms = l - 0.0894841775 * a_lab - 1.2914855480 * b_lab;
          const l3 = l_lms * l_lms * l_lms;
          const m3 = m_lms * m_lms * m_lms;
          const s3 = s_lms * s_lms * s_lms;
          const r_linear = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
          const g_linear = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
          const b_linear = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;
          const toSRGB = (c_lin) => {
            const clamped = Math.max(0, Math.min(1, c_lin));
            return clamped <= 0.0031308
              ? 12.92 * clamped
              : 1.055 * Math.pow(clamped, 1 / 2.4) - 0.055;
          };
          const r = Math.round(toSRGB(r_linear) * 255);
          const g = Math.round(toSRGB(g_linear) * 255);
          const b = Math.round(toSRGB(b_linear) * 255);
          return a < 1 ? `rgba(${r}, ${g}, ${b}, ${a})` : `rgb(${r}, ${g}, ${b})`;
        };

        const oklabToRgbLocal = (oklabStr) => {
          const match = oklabStr.match(/oklab\(([-.\d%.]+)\s+([-.\d%.]+)\s+([-.\d%.]+)(?:\s*\/\s*([-.\d%.]+))?\)/) ||
                        oklabStr.match(/oklab\(([-.\d%.]+),\s*([-.\d%.]+),\s*([-.\d%.]+)(?:,\s*([-.\d%.]+))?\)/);
          if (!match) return oklabStr;
          let l = parseFloat(match[1]);
          let a_lab = parseFloat(match[2]);
          let b_lab = parseFloat(match[3]);
          let a = match[4] !== undefined ? parseFloat(match[4]) : 1;
          if (match[1].includes('%')) l /= 100;
          if (match[2].includes('%')) a_lab /= 100;
          if (match[3].includes('%')) b_lab /= 100;
          const l_lms = l + 0.3963377774 * a_lab + 0.2158037573 * b_lab;
          const m_lms = l - 0.1055613458 * a_lab - 0.0638541728 * b_lab;
          const s_lms = l - 0.0894841775 * a_lab - 1.2914855480 * b_lab;
          const l3 = l_lms * l_lms * l_lms;
          const m3 = m_lms * m_lms * m_lms;
          const s3 = s_lms * s_lms * s_lms;
          const r_linear = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
          const g_linear = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
          const b_linear = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;
          const toSRGB = (c_lin) => {
            const clamped = Math.max(0, Math.min(1, c_lin));
            return clamped <= 0.0031308
              ? 12.92 * clamped
              : 1.055 * Math.pow(clamped, 1 / 2.4) - 0.055;
          };
          const r = Math.round(toSRGB(r_linear) * 255);
          const g = Math.round(toSRGB(g_linear) * 255);
          const b = Math.round(toSRGB(b_linear) * 255);
          return a < 1 ? `rgba(${r}, ${g}, ${b}, ${a})` : `rgb(${r}, ${g}, ${b})`;
        };

        const convertCSSColors = (str) => {
          if (typeof str !== "string") return str;
          
          // Match oklch/oklab with signed floats/percentages and spaces/slashes
          let out = str.replace(/oklch\(([^)]+)\)/g, (m) => oklchToRgbLocal(m));
          out = out.replace(/oklab\(([^)]+)\)/g, (m) => oklabToRgbLocal(m));
          return out;
        };

        window.getComputedStyle = function(el, pseudo) {
          const style = originalGetComputedStyle(el, pseudo);
          return new Proxy(style, {
            get(target, prop) {
              const val = target[prop];
              if (typeof val === "string") {
                return convertCSSColors(val);
              }
              if (prop === "getPropertyValue") {
                return function(propertyName) {
                  const originalVal = target.getPropertyValue(propertyName);
                  return convertCSSColors(originalVal);
                };
              }
              if (typeof val === "function") {
                return val.bind(target);
              }
              return val;
            }
          });
        };

        // Capture Pitch
        html2canvas(pitchEl, {
          backgroundColor: "#000000",
          scale: 2,
          useCORS: true,
          logging: false
        }).then(pitchCanvas => {
          // Capture Standings / Results Table
          const tableCard = document.getElementById("standings-table-card");
          if (!tableCard) {
            window.getComputedStyle = originalGetComputedStyle;
            return;
          }
          
          html2canvas(tableCard, {
            backgroundColor: "#111111",
            scale: 2,
            useCORS: true,
            logging: false
          }).then(detailsCanvas => {
            // Restore original getComputedStyle
            window.getComputedStyle = originalGetComputedStyle;

            // Combine both canvas renderings into a single master canvas (stacked vertically)
            const combinedCanvas = document.createElement("canvas");
            const ctx = combinedCanvas.getContext("2d");

            // Calculate spacing and layout size
            const gap = 30;
            combinedCanvas.width = Math.max(pitchCanvas.width, detailsCanvas.width);
            combinedCanvas.height = pitchCanvas.height + detailsCanvas.height + gap;

            // Fill canvas background
            ctx.fillStyle = "#0a0a0a";
            ctx.fillRect(0, 0, combinedCanvas.width, combinedCanvas.height);

            // Draw Pitch
            const pitchX = (combinedCanvas.width - pitchCanvas.width) / 2;
            ctx.drawImage(pitchCanvas, pitchX, 0);

            // Draw Standings / Details Card below the pitch
            const detailsX = (combinedCanvas.width - detailsCanvas.width) / 2;
            ctx.drawImage(detailsCanvas, detailsX, pitchCanvas.height + gap);

            // Trigger single combined download
            triggerDownload(combinedCanvas, "invincibles-campaign.png");

            // Extract record parameters
            const wins = this.el.dataset.wins || "0";
            const draws = this.el.dataset.draws || "0";
            const losses = this.el.dataset.losses || "0";
            const points = this.el.dataset.points || "0";
            const season = this.el.dataset.season ? ` (${this.el.dataset.season})` : "";

            // Open Twitter share compose intent
            const tweetText = encodeURIComponent(`Can you build a squad and go 38-0-0? Check out my Invincibles lineup and season standings table!\n\nRecord: ${wins}W - ${draws}D - ${losses}L | ${points} Pts${season} ⚽🏆\n\n#InvinciblesDraft\n\n(Attach the downloaded invincibles-campaign.png from your downloads folder!)`);
            const twitterUrl = `https://twitter.com/intent/tweet?text=${tweetText}`;
            window.open(twitterUrl, "_blank");
          }).catch(err => {
            console.error("Standings capture failed:", err);
            window.getComputedStyle = originalGetComputedStyle;
          });
        }).catch(err => {
          console.error("Pitch capture failed:", err);
          window.getComputedStyle = originalGetComputedStyle;
        });
      });
    }
  },

  DragDropLineup: {
    mounted() {
      this.el.addEventListener("dragstart", e => {
        const card = e.target.closest("[draggable='true']");
        if (!card) return;
        const appId = card.dataset.appearanceId;
        const rawPositions = card.dataset.positions || "";
        const positions = rawPositions.split(",").filter(Boolean);

        e.dataTransfer.setData("text/plain", appId);
        e.dataTransfer.effectAllowed = "move";

        // Highlight eligible slots
        const slots = this.el.querySelectorAll(".pitch-slot");
        slots.forEach(slot => {
          const posKey = slot.dataset.positionKey;
          if (positions.includes(posKey)) {
            slot.classList.add("ring-4", "ring-indigo-400", "ring-offset-2", "ring-offset-slate-900", "animate-pulse");
          } else {
            slot.classList.add("opacity-30");
          }
        });
      });

      this.el.addEventListener("dragend", e => {
        const slots = this.el.querySelectorAll(".pitch-slot");
        slots.forEach(slot => {
          slot.classList.remove("ring-4", "ring-indigo-400", "ring-offset-2", "ring-offset-slate-900", "animate-pulse", "opacity-30");
        });
      });

      this.el.addEventListener("dragover", e => {
        if (e.target.closest(".pitch-slot.ring-4")) {
          e.preventDefault();
          e.dataTransfer.dropEffect = "move";
        }
      });

      this.el.addEventListener("drop", e => {
        const slot = e.target.closest(".pitch-slot.ring-4");
        if (!slot) return;
        e.preventDefault();

        const appId = e.dataTransfer.getData("text/plain");
        const posKey = slot.dataset.positionKey;

        if (appId && posKey) {
          this.pushEvent("draft_player", {
            "appearance-id": appId,
            "position-key": posKey
          });
        }
      });
    }
  }
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

function triggerDownload(canvas, filename) {
  const link = document.createElement("a");
  link.download = filename || "invincibles-squad.png";
  link.href = canvas.toDataURL("image/png");
  link.click();
}


