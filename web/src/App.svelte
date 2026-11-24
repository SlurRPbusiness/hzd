<script>
  import { onMount } from "svelte";
  import DevModePanel from "./components/devmode/DevModePanel.svelte";
  import NotificationCard from "./components/notifications/NotificationCard.svelte";
  import { SUPPORTED_POSITIONS, resolvePosition } from "./utils/positions.js";
  import { getSessionToken, initializeSecurity, isFiveM, postNUI, setSessionToken } from "./utils/security.js";

  const positions = SUPPORTED_POSITIONS;
  let notifications = $state([]);
  let translations = $state({});
  let language = $state("it");
  let devMode = $state(false);
  let sessionToken = $state("");
  let translationCount = $derived(countStrings(translations));
  let sequence = 0;

  function countStrings(value) {
    if (typeof value === "string") return 1;
    if (!value || typeof value !== "object") return 0;
    return Object.values(value).reduce((total, child) => total + countStrings(child), 0);
  }

  function t(key, ...values) {
    let value = translations;
    for (const segment of key.split(".")) value = value?.[segment];
    let text = typeof value === "string" ? value : key;
    for (const parameter of values) text = text.replace("%s", String(parameter));
    return text;
  }

  function applyLocale(payload) {
    if (!payload || typeof payload !== "object") return;
    if (typeof payload.language === "string") {
      language = payload.language;
      document.documentElement.lang = language;
    }
    if (payload.translations && typeof payload.translations === "object") {
      translations = payload.translations;
    }
  }

  function notify(options) {
    const input = typeof options === "string" ? { message: options } : options;
    if (!input || typeof input !== "object") return null;

    const id = String(input.id ?? `nui_${Date.now()}_${++sequence}`);
    const position = resolvePosition(input.position);
    const current = notifications.filter((item) => item.position === position && !item.closing);

    if (current.length >= 5) dismiss(current[0].id);

    notifications = [
      ...notifications.filter((item) => item.id !== id),
      {
        id,
        title: typeof input.title === "string" ? input.title : "",
        message: typeof input.message === "string" ? input.message : String(input.message ?? ""),
        badge: typeof input.badge === "string" ? input.badge : "",
        icon: typeof input.icon === "string" ? input.icon : "",
        type: typeof input.type === "string" ? input.type : "info",
        position,
        duration: Number.isFinite(Number(input.duration)) ? Number(input.duration) : 4000,
        sound: input.sound !== false,
        closing: false,
      },
    ];

    return id;
  }

  function dismiss(id) {
    notifications = notifications.map((item) => item.id === id ? { ...item, closing: true } : item);
  }

  function clearAll() {
    notifications = notifications.map((item) => ({ ...item, closing: true }));
  }

  function removeNotification(id) {
    notifications = notifications.filter((item) => item.id !== id);
  }

  function handleMessage(event) {
    const envelope = event.data;
    if (!envelope || typeof envelope !== "object") return;

    if (typeof envelope.token === "string") {
      setSessionToken(envelope.token);
      sessionToken = getSessionToken() || "";
    }

    if (typeof envelope.devMode === "boolean") devMode = envelope.devMode;

    switch (envelope.action) {
      case "__handshake":
        applyLocale(envelope);
        break;
      case "setLocale":
        applyLocale(envelope.data);
        break;
      case "notify":
        notify(envelope.data);
        break;
      case "dismiss":
        if (envelope.data?.id) dismiss(envelope.data.id);
        break;
      case "clearAll":
        clearAll();
        break;
      case "setDevMode":
        devMode = envelope.data?.enabled === true;
        break;
    }
  }

  function handleKeydown(event) {
    if (event.key === "Escape") postNUI("exitFocus");
  }

  onMount(() => {
    window.addEventListener("message", handleMessage);
    window.addEventListener("keydown", handleKeydown);

    const api = {
      notifications: { notify, dismiss, clearAll },
      get devMode() { return devMode; },
      setBrowserDevMode(value) {
        if (!isFiveM()) devMode = value === true;
      },
    };
    window.appleUI = api;

    let mounted = true;
    initializeSecurity().then((result) => {
      if (!mounted || !result.success) return;
      if (typeof result.token === "string") {
        setSessionToken(result.token);
        sessionToken = result.token;
      }
      if (typeof result.devMode === "boolean") devMode = result.devMode;
      applyLocale(result);
    });

    return () => {
      mounted = false;
      window.removeEventListener("message", handleMessage);
      window.removeEventListener("keydown", handleKeydown);
      if (window.appleUI === api) delete window.appleUI;
    };
  });
</script>

<main aria-live="polite">
  {#each positions as position (position)}
    <div class={`apple-notification-container pos-${position}`} data-position={position}>
      {#each notifications.filter((item) => item.position === position) as notification (notification.id)}
        <NotificationCard {notification} onDismiss={removeNotification} translate={t} />
      {/each}
    </div>
  {/each}

  {#if devMode}
    <DevModePanel
      visible={devMode}
      {t}
      {notify}
      {clearAll}
      {language}
      {translationCount}
      token={sessionToken}
    />
  {/if}
</main>
