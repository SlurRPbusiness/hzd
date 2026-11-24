/**
 * ============================================================================
 * Apple UI Root Orchestrator
 * Inizializzazione, Gestione Messaggi NUI FiveM ed Eventi di Gioco
 * ============================================================================
 */

import { initializeSecurity, setSessionToken, postNUI } from "./utils/security.js";
import { NotificationManager } from "./components/notifications/NotificationManager.js";
import { DevModePanel } from "./components/devmode/DevModePanel.js";

// Inizializza il gestore delle notifiche
const notificationManager = new NotificationManager();

// Inizializza il pannello Dev Mode (nascosto di default, visibile se attivato o su browser)
const devPanel = new DevModePanel({
  manager: notificationManager,
  initiallyVisible: false,
});

// Listener per i messaggi provenienti dal client Lua (SendNUIMessage)
window.addEventListener("message", (event) => {
  const envelope = event.data;
  if (!envelope || typeof envelope !== "object") return;

  const { action, data, token, devMode } = envelope;

  // Se è presente un token nell'envelope, aggiorna il layer di sicurezza locale
  if (token) {
    setSessionToken(token);
    devPanel.updateTokenDisplay();
  }

  switch (action) {
    case "__handshake": {
      if (typeof devMode === "boolean") {
        devPanel.setVisible(devMode);
      }
      break;
    }

    case "notify": {
      if (data) {
        notificationManager.notify(data);
      }
      break;
    }

    case "dismiss": {
      if (data && data.id) {
        notificationManager.dismiss(data.id);
      }
      break;
    }

    case "clearAll": {
      notificationManager.clearAll();
      break;
    }

    case "setDevMode": {
      const isDev = !!(data && data.enabled);
      devPanel.setVisible(isDev);
      break;
    }

    default:
      break;
  }
});

// Gestione tasto ESCAPE per rilasciare il cursore/focus in gioco
window.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    postNUI("exitFocus");
  }
});

// Avvia l'handshake all'avvio della pagina web
document.addEventListener("DOMContentLoaded", async () => {
  const result = await initializeSecurity();
  if (result.success) {
    devPanel.updateTokenDisplay();
    // Se siamo su browser di test, mostra automaticamente il pannello per comodità
    if (result.devMode) {
      devPanel.setVisible(true);
    }
  }
});

// Esporta istanza globale per eventuale accesso console dev
window.appleUI = {
  notifications: notificationManager,
  devPanel,
};

