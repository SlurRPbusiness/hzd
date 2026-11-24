/**
 * ============================================================================
 * Apple Notification Manager Component
 * Gestore centralizzato dei contenitori a schermo, stacking e code di notifiche
 * ============================================================================
 */

import { NotificationCard } from "./NotificationCard.js";
import { resolvePosition, getPositionClass } from "../../utils/positions.js";

export class NotificationManager {
  constructor() {
    this.containers = new Map();
    this.activeCards = new Map();
    this.maxPerPosition = 5;
  }

  /**
   * Restituisce o crea al volo il contenitore DOM per la posizione specificata
   * @param {string} position Posizione canonica
   * @returns {HTMLElement}
   */
  getContainer(position) {
    const canonical = resolvePosition(position);

    if (this.containers.has(canonical)) {
      return this.containers.get(canonical);
    }

    const container = document.createElement("div");
    container.className = `apple-notification-container ${getPositionClass(canonical)}`;
    container.setAttribute("data-position", canonical);
    document.body.appendChild(container);

    this.containers.set(canonical, container);
    return container;
  }

  /**
   * Spawna e mostra una nuova notifica stile Apple con fisica a molla
   * @param {object} options Opzioni notifica
   * @returns {string} Identificativo univoco notifica
   */
  notify(options) {
    const canonicalPosition = resolvePosition(options.position);
    const container = this.getContainer(canonicalPosition);

    const id = options.id || ("notif_" + Date.now() + "_" + Math.floor(Math.random() * 1000));

    // Gestione limite massimo di notifiche contemporanee per contenitore
    const currentChildren = Array.from(container.children);
    if (currentChildren.length >= this.maxPerPosition) {
      const oldestElement = currentChildren[0];
      const oldestId = oldestElement.id;
      if (this.activeCards.has(oldestId)) {
        this.activeCards.get(oldestId).dismissWithSpring();
      }
    }

    const card = new NotificationCard({
      ...options,
      id,
      position: canonicalPosition,
      onDismiss: (dismissedId) => {
        this.activeCards.delete(dismissedId);
      },
    });

    this.activeCards.set(id, card);
    card.mount(container);

    return id;
  }

  /**
   * Rimuove una notifica specifica tramite ID
   * @param {string} id 
   */
  dismiss(id) {
    if (this.activeCards.has(id)) {
      this.activeCards.get(id).dismissWithSpring();
    }
  }

  /**
   * Chiude tutte le notifiche attive con un'animazione a cascata
   */
  clearAll() {
    let delay = 0;
    this.activeCards.forEach((card) => {
      setTimeout(() => {
        card.dismissWithSpring();
      }, delay);
      delay += 50;
    });
  }
}

