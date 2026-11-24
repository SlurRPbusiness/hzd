/**
 * ============================================================================
 * Apple Haptic Audio Synthesizer (Web Audio API)
 * Genera feedback acustici fluidi stile Apple senza dipendere da file esterni
 * ============================================================================
 */

let audioCtx = null;

function getAudioContext() {
  if (!audioCtx) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (AudioContextClass) {
      audioCtx = new AudioContextClass();
    }
  }
  if (audioCtx && audioCtx.state === "suspended") {
    audioCtx.resume();
  }
  return audioCtx;
}

/**
 * Riproduce un feedback sonoro fluido e sottile in base al tipo di evento
 * @param {"info"|"success"|"warning"|"error"|"pvp"|"kill"|"streak"|"headshot"|"click"|"dismiss"} type 
 */
export function playSound(type = "info") {
  try {
    const ctx = getAudioContext();
    if (!ctx) return;

    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.connect(gain);
    gain.connect(ctx.destination);

    switch (type) {
      case "kill":
      case "pvp": {
        // Suono potente e netto per eliminazione PvP
        osc.type = "sine";
        osc.frequency.setValueAtTime(320, now);
        osc.frequency.exponentialRampToValueAtTime(120, now + 0.16);

        gain.gain.setValueAtTime(0.22, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);

        osc.start(now);
        osc.stop(now + 0.18);
        break;
      }

      case "headshot":
      case "streak": {
        // Tono acuto scintillante stile Apple per headshot/streak
        osc.type = "triangle";
        osc.frequency.setValueAtTime(587.33, now); // D5
        osc.frequency.setValueAtTime(880, now + 0.05); // A5

        gain.gain.setValueAtTime(0.18, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.22);

        osc.start(now);
        osc.stop(now + 0.22);
        break;
      }

      case "success": {
        // Chime armonico a due toni Apple
        osc.type = "sine";
        osc.frequency.setValueAtTime(523.25, now); // C5
        osc.frequency.exponentialRampToValueAtTime(659.25, now + 0.08); // E5

        gain.gain.setValueAtTime(0.12, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);

        osc.start(now);
        osc.stop(now + 0.2);
        break;
      }

      case "warning":
      case "error": {
        // Tono basso smorzato per avvisi ed errori
        osc.type = "sine";
        osc.frequency.setValueAtTime(240, now);
        osc.frequency.linearRampToValueAtTime(180, now + 0.12);

        gain.gain.setValueAtTime(0.15, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.14);

        osc.start(now);
        osc.stop(now + 0.14);
        break;
      }

      case "click": {
        // Feedback haptic ultra-rapido (pointerdown)
        osc.type = "sine";
        osc.frequency.setValueAtTime(800, now);
        osc.frequency.exponentialRampToValueAtTime(400, now + 0.03);

        gain.gain.setValueAtTime(0.05, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.035);

        osc.start(now);
        osc.stop(now + 0.035);
        break;
      }

      case "dismiss": {
        // Woosh leggero alla rimozione
        osc.type = "sine";
        osc.frequency.setValueAtTime(400, now);
        osc.frequency.exponentialRampToValueAtTime(150, now + 0.1);

        gain.gain.setValueAtTime(0.08, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.12);

        osc.start(now);
        osc.stop(now + 0.12);
        break;
      }

      case "info":
      default: {
        // Tipico pop delicato Apple
        osc.type = "sine";
        osc.frequency.setValueAtTime(659.25, now); // E5
        osc.frequency.exponentialRampToValueAtTime(783.99, now + 0.06); // G5

        gain.gain.setValueAtTime(0.1, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.16);

        osc.start(now);
        osc.stop(now + 0.16);
        break;
      }
    }
  } catch {
    // Gestione silenziosa in caso di mancato supporto audio
  }
}

