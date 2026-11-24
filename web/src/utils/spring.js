/**
 * ============================================================================
 * Apple Fluid Spring Physics Engine
 * Implementazione delle formule matematiche WWDC 2018 "Designing Fluid Interfaces"
 * ============================================================================
 */

/**
 * Formula Apple per la resistenza al bordo (Rubber-Banding)
 * @param {number} offset Spostamento oltre il limite
 * @param {number} dimension Dimensione dell'elemento
 * @param {number} [constant=0.55] Costante di resistenza elastica
 * @returns {number} Offset attenuato con resistenza progressiva
 */
export function rubberBand(offset, dimension, constant = 0.55) {
  if (dimension <= 0) return offset;
  const sign = offset < 0 ? -1 : 1;
  const absOffset = Math.abs(offset);
  const resisted = (1 - (1 / ((absOffset * constant / dimension) + 1))) * dimension;
  return sign * resisted;
}

/**
 * Proiezione del punto di atterraggio basata sul momento (Momentum Projection)
 * @param {number} current Posizione attuale
 * @param {number} velocity Velocità in pixel per secondo
 * @param {number} [decayConstant=0.998] Fattore di decadimento
 * @returns {number} Posizione stimata di arresto naturale
 */
export function projectMomentum(current, velocity, decayConstant = 0.998) {
  return current + (velocity / 1000) * (decayConstant / (1 - decayConstant));
}

/**
 * Tracker di velocità e posizione per gesture con puntatore
 */
export class VelocityTracker {
  constructor() {
    this.history = [];
    this.maxHistory = 5;
  }

  addPoint(position, timestamp = performance.now()) {
    this.history.push({ position, timestamp });
    if (this.history.length > this.maxHistory) {
      this.history.shift();
    }
  }

  /**
   * Calcola la velocità al momento del rilascio (in pixel/secondo)
   * @returns {number}
   */
  getVelocity() {
    if (this.history.length < 2) return 0;

    const oldest = this.history[0];
    const newest = this.history[this.history.length - 1];
    const deltaPos = newest.position - oldest.position;
    const deltaTime = (newest.timestamp - oldest.timestamp) / 1000; // in secondi

    if (deltaTime <= 0.001) return 0;
    return deltaPos / deltaTime;
  }

  reset() {
    this.history = [];
  }
}

/**
 * Animatore a molla numerico basato su equazioni differenziali fisiche
 */
export class SpringAnimation {
  /**
   * @param {object} options
   * @param {number} [options.stiffness=220] Rigidità della molla
   * @param {number} [options.damping=26] Smorzamento (critico ≈ 2 * sqrt(stiffness))
   * @param {number} [options.mass=1] Massa
   * @param {number} [options.precision=0.5] Soglia di stop
   * @param {function} options.onUpdate Callback con valore corrente
   * @param {function} [options.onComplete] Callback al termine
   */
  constructor({ stiffness = 220, damping = 26, mass = 1, precision = 0.5, onUpdate, onComplete }) {
    this.stiffness = stiffness;
    this.damping = damping;
    this.mass = mass;
    this.precision = precision;
    this.onUpdate = onUpdate;
    this.onComplete = onComplete;

    this.current = 0;
    this.target = 0;
    this.velocity = 0;
    this.animFrameId = null;
    this.lastTime = 0;
  }

  start(from, to, initialVelocity = 0) {
    this.stop();
    this.current = from;
    this.target = to;
    this.velocity = initialVelocity;
    this.lastTime = performance.now();

    const loop = (now) => {
      let dt = (now - this.lastTime) / 1000;
      this.lastTime = now;
      if (dt > 0.064) dt = 0.064; // Limita grandi salti temporali

      // F = -k * x - c * v
      const displacement = this.current - this.target;
      const springForce = -this.stiffness * displacement;
      const dampingForce = -this.damping * this.velocity;
      const acceleration = (springForce + dampingForce) / this.mass;

      this.velocity += acceleration * dt;
      this.current += this.velocity * dt;

      if (this.onUpdate) {
        this.onUpdate(this.current, this.velocity);
      }

      // Condizione di arresto quando la molla è a riposo
      if (Math.abs(displacement) < this.precision && Math.abs(this.velocity) < this.precision * 2) {
        this.current = this.target;
        this.velocity = 0;
        if (this.onUpdate) this.onUpdate(this.current, 0);
        if (this.onComplete) this.onComplete();
        this.animFrameId = null;
        return;
      }

      this.animFrameId = requestAnimationFrame(loop);
    };

    this.animFrameId = requestAnimationFrame(loop);
  }

  stop() {
    if (this.animFrameId) {
      cancelAnimationFrame(this.animFrameId);
      this.animFrameId = null;
    }
  }
}

