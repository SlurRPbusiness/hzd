/**
 * ============================================================================
 * NUI Security & Handshake Layer
 * Gestisce handshake e token di sessione tra CEF e client Lua FiveM
 * ============================================================================
 */

import mockTranslations from "../../../locales/it/nui.json";

let sessionToken = null;
let resourceName = "lib";
let isFiveMEnvironment = false;

// Verifica se siamo nell'ambiente CEF di FiveM
try {
  if (typeof window.GetParentResourceName === "function") {
    resourceName = window.GetParentResourceName();
    isFiveMEnvironment = true;
  }
} catch {
  isFiveMEnvironment = false;
}

/**
 * Inizializza l'handshake sicuro con il client Lua.
 * @returns {Promise<{ success: boolean, token?: string }>}
 */
export async function initializeSecurity() {
  if (!isFiveMEnvironment) {
    // Modalità Browser Standalone (Sviluppo Locale)
    sessionToken = "dev-mock-token-" + Math.random().toString(36).substring(2, 9);
    console.log("%c[NUI Security] Modalità sviluppo browser attiva.", "color: #30d158; font-weight: bold;");
    return { success: true, token: sessionToken, devMode: true, language: "it", translations: mockTranslations };
  }

  try {
    const response = await fetch(`https://${resourceName}/__init_handshake`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify({ ready: true }),
    });

    if (!response.ok) {
      throw new Error(`Handshake fallito con status ${response.status}`);
    }

    const data = await response.json();
    if (data && data.token) {
      sessionToken = data.token;
      resourceName = data.resource || resourceName;
      console.log("%c[NUI Security] Handshake stabilito con successo.", "color: #30d158; font-weight: bold;");
      return {
        success: true,
        token: sessionToken,
        devMode: data.devMode === true,
        language: data.language,
        translations: data.translations,
      };
    }

    throw new Error("Token non presente nella risposta");
  } catch (err) {
    console.warn("[NUI Security] Tentativo handshake fallito:", err);
    return { success: false, error: err.message };
  }
}

/**
 * Imposta o aggiorna manualmente il token di sessione (ad es. da messaggio envelope).
 * @param {string} token 
 */
export function setSessionToken(token) {
  if (typeof token === "string" && token.length > 0) {
    sessionToken = token;
  }
}

/**
 * Restituisce il token di sessione corrente.
 * @returns {string|null}
 */
export function getSessionToken() {
  return sessionToken;
}

/**
 * Verifica se l'ambiente è il gioco FiveM.
 * @returns {boolean}
 */
export function isFiveM() {
  return isFiveMEnvironment;
}

/**
 * Invia una richiesta POST autenticata alla risorsa FiveM con token anti-manomissione.
 * @param {string} action Nome callback
 * @param {object} [data={}] Dati da inviare
 * @returns {Promise<any>}
 */
export async function postNUI(action, data = {}) {
  if (!isFiveMEnvironment) {
    console.log(`%c[NUI POST Mock] ${action}:`, "color: #0a84ff;", data);
    return { success: true, mock: true };
  }

  const payload = {
    ...data,
    __token: sessionToken,
  };

  try {
    const response = await fetch(`https://${resourceName}/${action}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
        "x-nui-token": sessionToken || "",
      },
      body: JSON.stringify(payload),
    });

    return await response.json();
  } catch (err) {
    console.error(`[NUI POST Error] Chiamata a '${action}' fallita:`, err);
    return { success: false, error: err.message };
  }
}

