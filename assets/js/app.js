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
        const area = document.getElementById("share-capture-area");
        if (!area) return;

        // Save original styling
        const originalBorder = area.style.border;
        area.style.border = "none";

        // Intercept getComputedStyle to bypass oklch/oklab failures in html2canvas
        const originalGetComputedStyle = window.getComputedStyle;
        window.getComputedStyle = function(el, pseudo) {
          const style = originalGetComputedStyle(el, pseudo);
          return new Proxy(style, {
            get(target, prop) {
              const val = target[prop];
              if (typeof val === "string") {
                if (val.includes("oklch(")) return oklchToRgb(val);
                if (val.includes("oklab(")) return oklabToRgb(val);
              }
              if (prop === "getPropertyValue") {
                return function(propertyName) {
                  const originalVal = target.getPropertyValue(propertyName);
                  if (typeof originalVal === "string") {
                    if (originalVal.includes("oklch(")) return oklchToRgb(originalVal);
                    if (originalVal.includes("oklab(")) return oklabToRgb(originalVal);
                  }
                  return originalVal;
                };
              }
              if (typeof val === "function") {
                return val.bind(target);
              }
              return val;
            }
          });
        };


        html2canvas(area, {
          backgroundColor: "#000000",
          scale: 2,
          useCORS: true,
          logging: false
        }).then(canvas => {
          // Restore getComputedStyle and styling
          window.getComputedStyle = originalGetComputedStyle;
          area.style.border = originalBorder;

          canvas.toBlob(blob => {
            if (!blob) return;
            const file = new File([blob], "invincibles-squad.png", { type: "image/png" });
            
            if (navigator.canShare && navigator.canShare({ files: [file] })) {
              navigator.share({
                files: [file],
                title: "My Invincibles Squad",
                text: "Can you go 38-0-0? Check out my squad and record!"
              }).catch(err => {
                console.error("Share failed:", err);
                triggerDownload(canvas);
              });
            } else {
              triggerDownload(canvas);
            }
          }, "image/png");
        }).catch(err => {
          console.error("html2canvas failed:", err);
          window.getComputedStyle = originalGetComputedStyle;
          area.style.border = originalBorder;
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

function triggerDownload(canvas) {
  const link = document.createElement("a");
  link.download = "invincibles-squad.png";
  link.href = canvas.toDataURL("image/png");
  link.click();
}


