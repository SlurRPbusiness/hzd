/**
 * ============================================================================
 * Apple SF Symbols & PvP Brand Logo Generator
 * Fornisce icone vettoriali precise stile Apple & icone dedicate al PvP
 * ============================================================================
 */

const ICONS = {
  // PvP & Combattimento
  pvp: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <polygon points="14.5 17.5 3 6 3 3 6 3 17.5 14.5"></polygon>
      <line x1="13" y1="19" x2="19" y2="13"></line>
      <line x1="16" y1="16" x2="20" y2="20"></line>
      <line x1="19" y1="21" x2="21" y2="19"></line>
    </svg>
  `,

  kill: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="10"></circle>
      <line x1="22" y1="12" x2="18" y2="12"></line>
      <line x1="6" y1="12" x2="2" y2="12"></line>
      <line x1="12" y1="6" x2="12" y2="2"></line>
      <line x1="12" y1="22" x2="12" y2="18"></line>
      <circle cx="12" cy="12" r="3" fill="currentColor"></circle>
    </svg>
  `,

  headshot: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 2a5 5 0 0 0-5 5v3a5 5 0 0 0 10 0V7a5 5 0 0 0-5-5z"></path>
      <path d="M19 14v1a7 7 0 0 1-14 0v-1"></path>
      <line x1="12" y1="8" x2="12" y2="12"></line>
      <circle cx="12" cy="5" r="1" fill="currentColor"></circle>
    </svg>
  `,

  streak: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"></path>
    </svg>
  `,

  // Notifiche di Sistema Apple
  info: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="10"></circle>
      <line x1="12" y1="16" x2="12" y2="12"></line>
      <line x1="12" y1="8" x2="12.01" y2="8"></line>
    </svg>
  `,

  success: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
      <polyline points="22 4 12 14.01 9 11.01"></polyline>
    </svg>
  `,

  warning: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
      <line x1="12" y1="9" x2="12" y2="13"></line>
      <line x1="12" y1="17" x2="12.01" y2="17"></line>
    </svg>
  `,

  error: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="10"></circle>
      <line x1="15" y1="9" x2="9" y2="15"></line>
      <line x1="9" y1="9" x2="15" y2="15"></line>
    </svg>
  `,

  shield: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
    </svg>
  `,

  crown: `
    <svg class="card-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M2 4l3 12h14l3-12-6 7-4-7-4 7-6-7zm3 16h14v2H5v-2z"></path>
    </svg>
  `,

  close: `
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
      <line x1="18" y1="6" x2="6" y2="18"></line>
      <line x1="6" y1="6" x2="18" y2="18"></line>
    </svg>
  `,
};

/**
 * Restituisce il logo/icona SVG formattato in base al tipo o al nome richiesto.
 * Supporta icone integrate, URL di immagini o stringhe SVG dirette.
 * @param {string} [type="info"] Tipo di icona (es: "pvp", "kill", "headshot", "streak", "success", ecc.)
 * @returns {string} Markup HTML dell'icona
 */
export function getLogo(type = "info") {
  if (!type || typeof type !== "string") {
    return ICONS.info;
  }

  const normalized = type.toLowerCase().trim();

  const isHttpsImage = /^https:\/\/[^\s"'<>]+$/i.test(type);
  const isLocalImage = /^(?!\/)(?!.*(?:^|\/)\.\.(?:\/|$))[\w./-]+\.(png|webp)$/i.test(type);

  if (isHttpsImage || isLocalImage) {
    const safeSource = type.replace(/[&<>"']/g, (character) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    })[character]);
    return `<img src="${safeSource}" class="card-icon-svg" alt="" style="object-fit: contain;" />`;
  }

  return ICONS[normalized] || ICONS.info;
}

/**
 * Restituisce l'icona di chiusura rapida standard Apple
 * @returns {string}
 */
export function getCloseIcon() {
  return ICONS.close;
}

