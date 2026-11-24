/**
 * ============================================================================
 * Position Aliases & Mapping
 * Gestione unificata e sicura delle posizioni a schermo per i componenti
 * ============================================================================
 */

export const POSITIONS = {
  TOP_RIGHT: "top-right",
  TOP_LEFT: "top-left",
  TOP_CENTER: "top-center",
  BOTTOM_RIGHT: "bottom-right",
  BOTTOM_LEFT: "bottom-left",
  BOTTOM_CENTER: "bottom-center",
};

/**
 * Mappa di alias flessibili per consentire sintassi abbreviata da Lua o JS
 */
const ALIAS_MAP = {
  "top-right": POSITIONS.TOP_RIGHT,
  "top_right": POSITIONS.TOP_RIGHT,
  "tr": POSITIONS.TOP_RIGHT,
  "right": POSITIONS.TOP_RIGHT,

  "top-left": POSITIONS.TOP_LEFT,
  "top_left": POSITIONS.TOP_LEFT,
  "tl": POSITIONS.TOP_LEFT,
  "left": POSITIONS.TOP_LEFT,

  "top-center": POSITIONS.TOP_CENTER,
  "top_center": POSITIONS.TOP_CENTER,
  "tc": POSITIONS.TOP_CENTER,
  "top": POSITIONS.TOP_CENTER,
  "center": POSITIONS.TOP_CENTER,

  "bottom-right": POSITIONS.BOTTOM_RIGHT,
  "bottom_right": POSITIONS.BOTTOM_RIGHT,
  "br": POSITIONS.BOTTOM_RIGHT,

  "bottom-left": POSITIONS.BOTTOM_LEFT,
  "bottom_left": POSITIONS.BOTTOM_LEFT,
  "bl": POSITIONS.BOTTOM_LEFT,

  "bottom-center": POSITIONS.BOTTOM_CENTER,
  "bottom_center": POSITIONS.BOTTOM_CENTER,
  "bc": POSITIONS.BOTTOM_CENTER,
  "bottom": POSITIONS.BOTTOM_CENTER,
};

/**
 * Risolve un alias di posizione restituendo la chiave canonica.
 * @param {string} [alias="top-right"] 
 * @returns {string} Posizione canonica normalizzata
 */
export function resolvePosition(alias) {
  if (!alias || typeof alias !== "string") {
    return POSITIONS.TOP_RIGHT;
  }
  const normalized = alias.toLowerCase().trim();
  return ALIAS_MAP[normalized] || POSITIONS.TOP_RIGHT;
}

/**
 * Restituisce la classe CSS corrispondente per il posizionamento del contenitore.
 * @param {string} position 
 * @returns {string}
 */
export function getPositionClass(position) {
  const canonical = resolvePosition(position);
  return `pos-${canonical}`;
}

/**
 * Elenco di tutte le posizioni supportate per selettori o menu dev
 * @type {string[]}
 */
export const SUPPORTED_POSITIONS = Object.values(POSITIONS);

