<script>
  import { onDestroy, onMount } from "svelte";
  import { getCloseIcon, getLogo } from "../../utils/logo.js";
  import { playSound } from "../../utils/audio.js";
  import { projectMomentum, rubberBand, SpringAnimation, VelocityTracker } from "../../utils/spring.js";

  let { notification, onDismiss, translate } = $props();
  let element;
  let progressBar;
  let isDragging = false;
  let isClosing = false;
  let startX = 0;
  let currentTranslateX = 0;
  let timerId;
  let startTime = 0;
  let remainingTime = notification.duration;
  let springAnim;
  let entryFrame;
  const velocityTracker = new VelocityTracker();

  function safeType(type) {
    return ["info", "success", "warning", "error", "pvp", "kill", "headshot", "streak"].includes(type)
      ? type
      : "info";
  }

  function dismissTarget() {
    return notification.position.includes("left") ? -400 : 400;
  }

  function startTimer() {
    if (notification.duration <= 0 || isClosing) return;
    startTime = performance.now();
    remainingTime = notification.duration;
    progressBar.style.transition = `transform ${remainingTime}ms linear`;
    progressBar.style.transform = "scaleX(0)";
    timerId = setTimeout(() => dismissWithSpring(dismissTarget()), remainingTime);
  }

  function pauseTimer() {
    if (timerId === undefined) return;
    clearTimeout(timerId);
    timerId = undefined;
    remainingTime = Math.max(0, remainingTime - (performance.now() - startTime));
    const computed = window.getComputedStyle(progressBar).transform;
    progressBar.style.transition = "none";
    progressBar.style.transform = computed;
  }

  function resumeTimer() {
    if (remainingTime <= 0 || timerId !== undefined || isClosing) return;
    startTime = performance.now();
    progressBar.style.transition = `transform ${remainingTime}ms linear`;
    progressBar.style.transform = "scaleX(0)";
    timerId = setTimeout(() => dismissWithSpring(dismissTarget()), remainingTime);
  }

  function handlePointerDown(event) {
    if (event.target.closest(".card-close-btn")) return;
    isDragging = true;
    startX = event.clientX;
    element.setPointerCapture(event.pointerId);
    springAnim?.stop();
    pauseTimer();
    velocityTracker.reset();
    velocityTracker.addPoint(event.clientX);
    playSound("click");
  }

  function handlePointerMove(event) {
    if (!isDragging) return;
    const deltaX = event.clientX - startX;
    velocityTracker.addPoint(event.clientX);

    let translated = deltaX;
    if (notification.position.includes("right") && deltaX < 0) translated = rubberBand(deltaX, 380, 0.45);
    else if (notification.position.includes("left") && deltaX > 0) translated = rubberBand(deltaX, 380, 0.45);

    currentTranslateX = translated;
    const width = element.offsetWidth || 340;
    element.style.transform = `translateX(${translated}px) scale(0.98)`;
    element.style.opacity = String(Math.max(0.2, 1 - Math.abs(translated) / (width * 1.4)));
  }

  function handlePointerUp(event) {
    if (!isDragging) return;
    isDragging = false;
    if (element.hasPointerCapture(event.pointerId)) element.releasePointerCapture(event.pointerId);

    const velocity = velocityTracker.getVelocity();
    const projected = projectMomentum(currentTranslateX, velocity);
    const width = element.offsetWidth || 340;
    const threshold = width * 0.38;
    const right = notification.position.includes("right");
    const left = notification.position.includes("left");
    let targetX = 0;

    if (right && (currentTranslateX > threshold || velocity > 400 || projected > threshold)) targetX = width + 80;
    else if (left && (currentTranslateX < -threshold || velocity < -400 || projected < -threshold)) targetX = -(width + 80);
    else if (!right && !left && (Math.abs(currentTranslateX) > threshold || Math.abs(velocity) > 400)) {
      targetX = currentTranslateX > 0 ? width + 80 : -(width + 80);
    }

    if (targetX !== 0) {
      dismissWithSpring(targetX, velocity);
      return;
    }

    springAnim = new SpringAnimation({
      stiffness: 280,
      damping: 24,
      onUpdate: (value) => {
        currentTranslateX = value;
        element.style.transform = `translateX(${value}px)`;
        element.style.opacity = "1";
      },
      onComplete: () => {
        element.style.transform = "";
        element.style.opacity = "";
        resumeTimer();
      },
    });
    springAnim.start(currentTranslateX, 0, velocity);
  }

  function dismissWithSpring(targetX = dismissTarget(), initialVelocity = 0) {
    if (isClosing) return;
    isClosing = true;
    pauseTimer();
    playSound("dismiss");

    springAnim = new SpringAnimation({
      stiffness: 200,
      damping: 22,
      onUpdate: (value) => {
        element.style.transform = `translateX(${value}px) scale(0.96)`;
        element.style.opacity = String(Math.max(0, 1 - Math.abs(value) / 300));
      },
      onComplete: () => onDismiss(notification.id),
    });
    springAnim.start(currentTranslateX, targetX, initialVelocity);
  }

  $effect(() => {
    if (notification.closing) dismissWithSpring();
  });

  onMount(() => {
    const right = notification.position.includes("right");
    const left = notification.position.includes("left");
    const offsetX = right ? 120 : left ? -120 : 0;
    const offsetY = offsetX === 0 ? -40 : 0;
    element.style.opacity = "0";
    element.style.transform = `translate(${offsetX}px, ${offsetY}px) scale(0.88)`;

    entryFrame = requestAnimationFrame(() => {
      springAnim = new SpringAnimation({
        stiffness: 240,
        damping: 22,
        onUpdate: (progress) => {
          element.style.transform = `translate(${offsetX * (1 - progress)}px, ${offsetY * (1 - progress)}px) scale(${0.88 + 0.12 * progress})`;
          element.style.opacity = String(progress);
        },
        onComplete: () => {
          element.style.transform = "";
          element.style.opacity = "";
          startTimer();
        },
      });
      springAnim.start(0, 1, 0);
    });
  });

  onDestroy(() => {
    if (timerId !== undefined) clearTimeout(timerId);
    if (entryFrame !== undefined) cancelAnimationFrame(entryFrame);
    springAnim?.stop();
  });
</script>

<article
  class={`apple-notification-card type-${safeType(notification.type)}`}
  bind:this={element}
  onpointerdown={handlePointerDown}
  onpointermove={handlePointerMove}
  onpointerup={handlePointerUp}
  onpointercancel={handlePointerUp}
  onpointerenter={pauseTimer}
  onpointerleave={() => { if (!isDragging) resumeTimer(); }}
>
  <div class="card-content-wrapper">
    <div class="card-icon-container">{@html getLogo(notification.icon || safeType(notification.type))}</div>
    <div class="card-text-body">
      <div class="card-header-row">
        <div class="card-title-group">
          {#if notification.title}<span class="card-title">{notification.title}</span>{/if}
          {#if notification.badge}<span class="card-badge">{notification.badge}</span>{/if}
        </div>
        <button
          class="card-close-btn"
          aria-label={translate("NUI.COMMON.CLOSE")}
          onclick={(event) => { event.stopPropagation(); dismissWithSpring(); }}
          onpointerdown={(event) => { event.stopPropagation(); playSound("click"); }}
        >
          {@html getCloseIcon()}
        </button>
      </div>
      <div class="card-message">{notification.message}</div>
    </div>
  </div>
  <div class="card-progress-track">
    <div class="card-progress-bar" bind:this={progressBar}></div>
  </div>
</article>
