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


