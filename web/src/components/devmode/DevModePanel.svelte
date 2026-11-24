<script>
  import { playSound } from "../../utils/audio.js";
  import { SUPPORTED_POSITIONS } from "../../utils/positions.js";
  import { isFiveM } from "../../utils/security.js";

  let { visible, t, notify, clearAll, language, translationCount, token } = $props();
  let expanded = $state(false);
  let selectedPosition = $state("top-right");

  const actions = [
    { key: "KILL", style: "btn-pvp-kill", test: "KILL" },
    { key: "HEADSHOT", style: "btn-pvp-headshot", test: "HEADSHOT" },
    { key: "STREAK", style: "btn-pvp-streak", test: "STREAK" },
    { key: "MATCH_INFO", style: "btn-system-info", test: "INFO" },
    { key: "WARNING", style: "btn-system-warn", test: "WARNING" },
    { key: "VICTORY", style: "btn-success", test: "VICTORY" },
  ];

  function triggerTest(key) {
    const prefix = `NUI.TEST.${key}`;
    const durations = { KILL: 4000, HEADSHOT: 4200, STREAK: 4500, VICTORY: 5000, WARNING: 4000, INFO: 3500 };
    notify({
      title: t(`${prefix}.TITLE`),
      badge: t(`${prefix}.BADGE`),
      message: t(`${prefix}.MESSAGE`),
      type: key === "VICTORY" ? "success" : key.toLowerCase(),
      position: selectedPosition,
      duration: durations[key],
    });
  }
</script>

<div class="devmode-dock-container" style:display={visible ? "flex" : "none"}>
  {#if expanded}
    <section class="devmode-expanded-hud active" aria-label={t("NUI.DEVMODE.TITLE")}>
      <header class="devmode-header">
        <div class="devmode-header-title">
          <span>{t("NUI.DEVMODE.TITLE")}</span>
          <span class="devmode-badge">
            {isFiveM() ? t("NUI.DEVMODE.BADGE_FIVEM") : t("NUI.DEVMODE.BADGE_BROWSER")}
          </span>
        </div>
        <div class="devmode-token-info" title={t("NUI.DEVMODE.TOKEN_LABEL")}>
          {t("NUI.DEVMODE.TOKEN_LABEL")}: <span class="token-val">
            {token ? `${token.slice(0, 12)}...` : t("NUI.DEVMODE.TOKEN_WAITING")}
          </span>
        </div>
      </header>

      <div class="devmode-section-label">{t("NUI.DEVMODE.SECTION")}</div>
      <div class="devmode-actions-grid">
        {#each actions as action (action.key)}
          <button class={`devmode-btn ${action.style}`} onclick={() => triggerTest(action.test)}>
            {t(`NUI.DEVMODE.${action.key}`)}
          </button>
        {/each}
        <button class="devmode-btn btn-system-clear" onclick={clearAll}>
          {t("NUI.DEVMODE.CLEAR")}
        </button>
      </div>

      <div class="devmode-controls-row">
        <label class="devmode-section-label" for="devmode-pos-select">{t("NUI.DEVMODE.POSITION")}</label>
        <select
          id="devmode-pos-select"
          class="devmode-select"
          bind:value={selectedPosition}
          onchange={() => playSound("click")}
        >
          {#each SUPPORTED_POSITIONS as position (position)}
            <option value={position}>{t(`NUI.POSITIONS.${position}`)}</option>
          {/each}
        </select>
      </div>

      <div class="devmode-locale-info">
        {t("NUI.DEVMODE.LOCALE")}: {language} · {translationCount} {t("NUI.DEVMODE.TRANSLATIONS")}
      </div>
    </section>
  {/if}

  <button
    class="devmode-toggle-pill"
    aria-label={t("NUI.DEVMODE.TOGGLE")}
    aria-expanded={expanded}
    onclick={() => {
      expanded = !expanded;
      playSound("click");
    }}
  >
    <span class="devmode-status-dot"></span>
    <span>DEV MODE</span>
  </button>
</div>
