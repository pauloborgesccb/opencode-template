// Trecho para src/config/app.ts (ou arquivo de config central do app).
// IDs reais da conta AdMob do app. `testing` vem de VITE_ADMOB_TESTING
// (.env.development / .env.production): builds *:dev servem anúncios de
// TESTE, builds *:prod servem anúncios REAIS. Nunca clique nos próprios
// anúncios em build prod.
export const ADMOB = {
  testing: import.meta.env.VITE_ADMOB_TESTING !== 'false',
  android: {
    banner: '{{ANDROID_BANNER_ID}}',
    interstitial: '{{ANDROID_INTERSTITIAL_ID}}',
  },
  ios: {
    banner: '{{IOS_BANNER_ID}}',
    interstitial: '{{IOS_INTERSTITIAL_ID}}',
  },
  /** Tempo máximo esperando o intersticial carregar antes de liberar o fluxo. */
  loadTimeoutMs: 8_000,
} as const;
