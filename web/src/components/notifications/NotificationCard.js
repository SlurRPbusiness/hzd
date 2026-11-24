/**
 * ============================================================================
 * Apple Notification Card Component
 * Scheda Notifica Interattiva con Fisica a Molla, Swipe Gestuale e Microinterazioni
 * ============================================================================
 */

import { getLogo, getCloseIcon } from "../../utils/logo.js";
import { playSound } from "../../utils/audio.js";
import { rubberBand, projectMomentum, VelocityTracker, SpringAnimation } from "../../utils/spring.js";

export class NotificationCard {
  /**
   * @param {object} options
   * @param {string} options.id Identificativo univoco
   * @param {string} [options.title] Titolo
   * @param {string} options.message Messaggio
   * @param {string} [options.type="info"] Tipo notifica
   * @param {number} [options.duration=4000] Durata
   * @param {string} [options.badge] Badge
   * @param {string} [options.position="top-right"] Posizione
   * @param {function} options.onDismiss Callback di chiusura
   */
  constructor(options) {
    this.options = {
      type: "info",
      duration: 4000,
      position: "top-right",
      sound: true,
      ...options,
    };

    this.onDismiss = options.onDismiss;
    this.element = null;
    this.progressBar = null;

    this.isDragging = false;
    this.startX = 0;
    this.currentTranslateX = 0;
    this.velocityTracker = new VelocityTracker();
    this.springAnim = null;

    this.timerId = null;
    this.startTime = 0;
    this.remainingTime = this.options.duration;

    this.initElement();
  }

  initElement() {
    const card = document.createElement("div");
    card.className = `apple-notification-card type-${this.options.type}`;
    card.id = this.options.id;

    const iconMarkup = getLogo(this.options.icon || this.options.type);
    const closeIconMarkup = getCloseIcon();
    const hasBadge = !!this.options.badge;
    const hasTitle = !!this.options.title;

    card.innerHTML = `
      <div class="card-content-wrapper">
        <div class="card-icon-container">
          ${iconMarkup}
        </div>
        <div class="card-text-body">
          <div class="card-header-row">
            <div class="card-title-group">
              ${hasTitle ? `<span class="card-title">${this.options.title}</span>` : ""}
              ${hasBadge ? `<span class="card-badge">${this.options.badge}</span>` : ""}
            </div>
            <button class="card-close-btn" aria-label="Chiudi notifica">
              ${closeIconMarkup}
            </button>
          </div>
          <div class="card-message">${this.options.message}</div>
        </div>
      </div>
      <div class="card-progress-track">
        <div class="card-progress-bar"></div>
      </div>
    `;

    this.element = card;
    this.progressBar = card.querySelector(".card-progress-bar");

    this.bindEvents();
  }

  bindEvents() {
    const closeBtn = this.element.querySelector(".card-close-btn");
    closeBtn.addEventListener("pointerdown", (e) => {
      e.stopPropagation();
      playSound("click");
    });
    closeBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      this.dismissWithSpring(400);
    });

    // Gestione Drag & Swipe 1:1 con Cattura Puntatore
    this.element.addEventListener("pointerdown", this.handlePointerDown.bind(this));
    this.element.addEventListener("pointermove", this.handlePointerMove.bind(this));
    this.element.addEventListener("pointerup", this.handlePointerUp.bind(this));
    this.element.addEventListener("pointercancel", this.handlePointerUp.bind(this));

    // Pausa del timer al passaggio del cursore
    this.element.addEventListener("pointerenter", () => this.pauseTimer());
    this.element.addEventListener("pointerleave", () => {
      if (!this.isDragging) this.resumeTimer();
    });
  }

  handlePointerDown(e) {
    if (e.target.closest(".card-close-btn")) return;

    this.isDragging = true;
    this.startX = e.clientX;
    this.element.setPointerCapture(e.pointerId);

    if (this.springAnim) {
      this.springAnim.stop();
    }

    this.pauseTimer();
    this.velocityTracker.reset();
    this.velocityTracker.addPoint(e.clientX);
    playSound("click");
  }

  handlePointerMove(e) {
    if (!this.isDragging) return;

    const deltaX = e.clientX - this.startX;
    this.velocityTracker.addPoint(e.clientX);

    // Determina la direzione preferenziale di chiusura in base alla posizione a schermo
    const isRightAligned = this.options.position.includes("right");
    const isLeftAligned = this.options.position.includes("left");

    let translated = deltaX;

    // Se si trascina in direzione opposta, applica resistenza elastica (Rubber-Banding)
    if (isRightAligned && deltaX < 0) {
      translated = rubberBand(deltaX, 380, 0.45);
    } else if (isLeftAligned && deltaX > 0) {
      translated = rubberBand(deltaX, 380, 0.45);
    }

    this.currentTranslateX = translated;
    const cardWidth = this.element.offsetWidth || 340;
    const opacity = Math.max(0.2, 1 - Math.abs(translated) / (cardWidth * 1.4));

    this.element.style.transform = `translateX(${translated}px) scale(0.98)`;
    this.element.style.opacity = `${opacity}`;
  }

  handlePointerUp(e) {
    if (!this.isDragging) return;
    this.isDragging = false;

    try {
      this.element.releasePointerCapture(e.pointerId);
    } catch {}

    const velocity = this.velocityTracker.getVelocity(); // px/secondo
    const projectedX = projectMomentum(this.currentTranslateX, velocity);
    const cardWidth = this.element.offsetWidth || 340;
    const threshold = cardWidth * 0.38;

    const isRight = this.options.position.includes("right");
    const isLeft = this.options.position.includes("left");

    // Decisione fluida: valuta posizione proiettata e segno della velocità al rilascio
    let shouldDismiss = false;
    let targetX = 0;

    if (isRight) {
      if (this.currentTranslateX > threshold || velocity > 400 || projectedX > threshold) {
        shouldDismiss = true;
        targetX = cardWidth + 80;
      }
    } else if (isLeft) {
      if (this.currentTranslateX < -threshold || velocity < -400 || projectedX < -threshold) {
        shouldDismiss = true;
        targetX = -(cardWidth + 80);
      }
    } else {
      // Centro: consente swipe in entrambe le direzioni
      if (Math.abs(this.currentTranslateX) > threshold || Math.abs(velocity) > 400) {
        shouldDismiss = true;
        targetX = this.currentTranslateX > 0 ? (cardWidth + 80) : -(cardWidth + 80);
      }
    }

    if (shouldDismiss) {
      this.dismissWithSpring(targetX, velocity);
    } else {
      // Rimbalza dolcemente alla posizione di riposo
      this.springAnim = new SpringAnimation({
        stiffness: 280,
        damping: 24,
        onUpdate: (val) => {
          this.currentTranslateX = val;
          this.element.style.transform = `translateX(${val}px)`;
          this.element.style.opacity = "1";
        },
        onComplete: () => {
          this.element.style.transform = "";
          this.element.style.opacity = "";
          this.resumeTimer();
        },
      });
      this.springAnim.start(this.currentTranslateX, 0, velocity);
    }
  }

  /**
   * Chiude la notifica animando con molla e rimuove dal DOM
   * @param {number} targetX 
   * @param {number} [initialVelocity=0] 
   */
  dismissWithSpring(targetX = 400, initialVelocity = 0) {
    this.pauseTimer();
    playSound("dismiss");

    this.springAnim = new SpringAnimation({
      stiffness: 200,
      damping: 22,
      onUpdate: (val) => {
        this.element.style.transform = `translateX(${val}px) scale(0.96)`;
        this.element.style.opacity = `${Math.max(0, 1 - Math.abs(val) / 300)}`;
      },
      onComplete: () => {
        if (this.element && this.element.parentElement) {
          this.element.remove();
        }
        if (typeof this.onDismiss === "function") {
          this.onDismiss(this.options.id);
        }
      },
    });

    this.springAnim.start(this.currentTranslateX, targetX, initialVelocity);
  }

  /**
   * Avvia l'animazione di ingresso con fisica a molla
   */
  mount(container) {
    container.appendChild(this.element);

    if (this.options.sound) {
      playSound(this.options.type);
    }

    // Configurazione entrata fluida
    const isRight = this.options.position.includes("right");
    const isLeft = this.options.position.includes("left");
    const startOffset = isRight ? 120 : (isLeft ? -120 : 0);
    const startOffsetY = (startOffset === 0) ? -40 : 0;

    this.element.style.opacity = "0";
    this.element.style.transform = `translate(${startOffset}px, ${startOffsetY}px) scale(0.88)`;

    // Esegue molla di ingresso criticamente smorzata
    requestAnimationFrame(() => {
      this.springAnim = new SpringAnimation({
        stiffness: 240,
        damping: 22,
        onUpdate: (progress) => {
          const curX = startOffset * (1 - progress);
          const curY = startOffsetY * (1 - progress);
          const curScale = 0.88 + 0.12 * progress;
          this.element.style.transform = `translate(${curX}px, ${curY}px) scale(${curScale})`;
          this.element.style.opacity = `${progress}`;
        },
        onComplete: () => {
          this.element.style.transform = "";
          this.element.style.opacity = "";
          this.startTimer();
        },
      });
      this.springAnim.start(0, 1, 0);
    });
  }

  startTimer() {
    if (this.options.duration <= 0) return; // Notifica persistente se duration <= 0

    this.startTime = performance.now();
    this.remainingTime = this.options.duration;

    this.progressBar.style.transition = `transform ${this.remainingTime}ms linear`;
    this.progressBar.style.transform = "scaleX(0)";

    this.timerId = setTimeout(() => {
      const isRight = this.options.position.includes("right");
      const target = isRight ? 380 : -380;
      this.dismissWithSpring(target);
    }, this.remainingTime);
  }

  pauseTimer() {
    if (!this.timerId) return;
    clearTimeout(this.timerId);
    this.timerId = null;

    const elapsed = performance.now() - this.startTime;
    this.remainingTime = Math.max(0, this.remainingTime - elapsed);

    // Blocca visivamente la barra di progresso al valore attuale
    if (this.progressBar) {
      const computed = window.getComputedStyle(this.progressBar).transform;
      this.progressBar.style.transition = "none";
      this.progressBar.style.transform = computed;
    }
  }

  resumeTimer() {
    if (this.remainingTime <= 0 || this.timerId) return;

    this.startTime = performance.now();
    this.progressBar.style.transition = `transform ${this.remainingTime}ms linear`;
    this.progressBar.style.transform = "scaleX(0)";

    this.timerId = setTimeout(() => {
      const isRight = this.options.position.includes("right");
      const target = isRight ? 380 : -380;
      this.dismissWithSpring(target);
    }, this.remainingTime);
  }
}

