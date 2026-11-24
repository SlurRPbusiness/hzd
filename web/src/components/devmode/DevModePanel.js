/**
 * ============================================================================
 * Apple Developer Mode HUD Component
 * Dock Fluttuante per Testing e Validazione Rapida dell'Interfaccia
 * ============================================================================
 */

import { playSound } from "../../utils/audio.js";
import { SUPPORTED_POSITIONS } from "../../utils/positions.js";
import { getSessionToken, isFiveM } from "../../utils/security.js";

export class DevModePanel {
  /**
   * @param {object} options
   * @param {import("../notifications/NotificationManager.js").NotificationManager} options.manager
   * @param {boolean} [options.initiallyVisible=false]
   */
  constructor({ manager, initiallyVisible = false }) {
    this.manager = manager;
    this.isVisible = initiallyVisible;
    this.isExpanded = false;
    this.selectedPosition = "top-right";
    this.element = null;

    this.initElement();
  }

  initElement() {
    const dock = document.createElement("div");
    dock.className = "devmode-dock-container";
    dock.style.display = this.isVisible ? "flex" : "none";

    const positionOptions = SUPPORTED_POSITIONS.map(
      (pos) => `<option value="${pos}" ${pos === "top-right" ? "selected" : ""}>${pos}</option>`
    ).join("");

    dock.innerHTML = `
      <div class="devmode-expanded-hud">
        <div class="devmode-header">
          <div class="devmode-header-title">
            <span>Apple UI Developer Mode</span>
            <span class="devmode-badge">${isFiveM() ? "FiveM CEF" : "Browser Mock"}</span>
          </div>
          <div class="devmode-token-info" title="Session Security Token">
            Token: <span class="token-val">${getSessionToken() ? getSessionToken().substring(0, 12) + "..." : "Attesa..."}</span>
          </div>
        </div>

        <div class="devmode-section-label">Azioni Rapide PvP & Sistema</div>
        <div class="devmode-actions-grid">
          <button class="devmode-btn btn-pvp-kill" data-type="kill">Kill +100</button>
          <button class="devmode-btn btn-pvp-headshot" data-type="headshot">Headshot</button>
          <button class="devmode-btn btn-pvp-streak" data-type="streak">3x Streak</button>
          <button class="devmode-btn btn-system-info" data-type="info">Info Match</button>
          <button class="devmode-btn btn-system-warn" data-type="warning">Zona Restretta</button>
          <button class="devmode-btn" data-type="success" style="border-left: 3px solid var(--color-apple-green);">Vittoria</button>
          <button class="devmode-btn btn-system-clear">Rimuovi Tutte</button>
        </div>

        <div class="devmode-controls-row">
          <label class="devmode-section-label" for="devmode-pos-select">Posizione:</label>
          <select id="devmode-pos-select" class="devmode-select">
            ${positionOptions}
          </select>
        </div>
      </div>

      <button class="devmode-toggle-pill" aria-label="Toggle Developer Panel">
        <span class="devmode-status-dot"></span>
        <span>DEV MODE</span>
      </button>
    `;

    this.element = dock;
    document.body.appendChild(dock);

    this.bindEvents();
  }

  bindEvents() {
    const toggleBtn = this.element.querySelector(".devmode-toggle-pill");
    const hud = this.element.querySelector(".devmode-expanded-hud");
    const posSelect = this.element.querySelector("#devmode-pos-select");

    toggleBtn.addEventListener("click", () => {
      this.isExpanded = !this.isExpanded;
      hud.classList.toggle("active", this.isExpanded);
      playSound("click");
    });

    posSelect.addEventListener("change", (e) => {
      this.selectedPosition = e.target.value;
      playSound("click");
    });

    // Delegazione click sui pulsanti di test
    this.element.addEventListener("click", (e) => {
      const btn = e.target.closest(".devmode-btn");
      if (!btn) return;

      if (btn.classList.contains("btn-system-clear")) {
        this.manager.clearAll();
        return;
      }

      const type = btn.getAttribute("data-type") || "info";
      this.triggerTestNotification(type);
    });
  }

  triggerTestNotification(type) {
    const pos = this.selectedPosition;

    switch (type) {
      case "kill":
        this.manager.notify({
          title: "ELIMINAZIONE PVP",
          badge: "+100 XP",
          message: "Hai abbattuto [ITA] Alex_Sniper con Heavy Sniper",
          type: "kill",
          position: pos,
          duration: 4000,
        });
        break;

      case "headshot":
        this.manager.notify({
          title: "COLPO ALLA TESTA",
          badge: "HEADSHOT +150",
          message: "Uccisione istantanea con colpo critico alla testa",
          type: "headshot",
          position: pos,
          duration: 4200,
        });
        break;

      case "streak":
        this.manager.notify({
          title: "SERIE UCCISIONI",
          badge: "3X KILLSTREAK",
          message: "Stai dominando l'arena! UAV tattico disponibile",
          type: "streak",
          position: pos,
          duration: 4500,
        });
        break;

      case "success":
        this.manager.notify({
          title: "ROUND VINTO",
          badge: "VITTORIA",
          message: "La tua squadra ha conquistato l'obiettivo principale (+500 Punti)",
          type: "success",
          position: pos,
          duration: 5000,
        });
        break;

      case "warning":
        this.manager.notify({
          title: "TEMPESTA IN ARRIVO",
          badge: "ATTENZIONE",
          message: "La zona sicura si restringerà entro 15 secondi",
          type: "warning",
          position: pos,
          duration: 4000,
        });
        break;

      case "info":
      default:
        this.manager.notify({
          title: "NOTIFICA DI SISTEMA",
          badge: "SISTEMA",
          message: "Caricamento statistiche e inventario completato",
          type: "info",
          position: pos,
          duration: 3500,
        });
        break;
    }
  }

  /**
   * Aggiorna la visibilità del dock dev mode
   * @param {boolean} visible 
   */
  setVisible(visible) {
    this.isVisible = visible;
    if (this.element) {
      this.element.style.display = visible ? "flex" : "none";
    }
  }

  /**
   * Aggiorna la visualizzazione del token
   */
  updateTokenDisplay() {
    const tokenSpan = this.element.querySelector(".token-val");
    const token = getSessionToken();
    if (tokenSpan && token) {
      tokenSpan.textContent = token.substring(0, 12) + "...";
    }
  }
}

