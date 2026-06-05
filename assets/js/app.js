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
import topbar from "../vendor/topbar"

const Hooks = {
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

