import { Capacitor } from '@capacitor/core';
import {
  AdMob,
  AdmobConsentStatus,
  BannerAdPosition,
  BannerAdSize,
  InterstitialAdPluginEvents,
} from '@capacitor-community/admob';
import { ADMOB } from '../config/app';

const native = Capacitor.isNativePlatform();
const ids = Capacitor.getPlatform() === 'ios' ? ADMOB.ios : ADMOB.android;

let initPromise: Promise<boolean> | null = null;
let bannerVisible = false;

/** Inicializa AdMob, pede consentimento (UMP/LGPD/GDPR) e rastreamento (ATT no iOS). */
export function initAds(): Promise<boolean> {
  if (!native) return Promise.resolve(false);
  initPromise ??= (async () => {
    try {
      await AdMob.initialize({ initializeForTesting: ADMOB.testing });

      const tracking = await AdMob.trackingAuthorizationStatus();
      if (tracking.status === 'notDetermined') await AdMob.requestTrackingAuthorization();

      try {
        const consent = await AdMob.requestConsentInfo();
        if (consent.isConsentFormAvailable && consent.status === AdmobConsentStatus.REQUIRED) {
          await AdMob.showConsentForm();
        }
      } catch (e) {
        // Consentimento só é obrigatório onde a lei exige (ex: GDPR na UE).
        // Sem formulário configurado/necessário, segue servindo anúncios.
        console.warn('[ads] consentimento indisponível', e);
      }
      return true;
    } catch (e) {
      console.warn('[ads] init falhou', e);
      return false;
    }
  })();
  return initPromise;
}

export async function showBanner(): Promise<void> {
  if (!(await initAds()) || bannerVisible) return;
  try {
    await AdMob.showBanner({
      adId: ids.banner,
      adSize: BannerAdSize.ADAPTIVE_BANNER,
      position: BannerAdPosition.BOTTOM_CENTER,
      margin: 0,
      isTesting: ADMOB.testing,
    });
    bannerVisible = true;
  } catch (e) {
    console.warn('[ads] banner', e);
  }
}

export async function removeBanner(): Promise<void> {
  if (!native || !bannerVisible) return;
  bannerVisible = false;
  try {
    await AdMob.removeBanner();
  } catch {
    /* banner já removido */
  }
}

let prepared: Promise<boolean> | null = null;

/** Carrega o próximo intersticial em segundo plano. */
export function preloadInterstitial(): Promise<boolean> {
  prepared ??= (async () => {
    if (!(await initAds())) return false;
    try {
      await AdMob.prepareInterstitial({ adId: ids.interstitial, isTesting: ADMOB.testing });
      return true;
    } catch (e) {
      console.warn('[ads] prepare interstitial', e);
      return false;
    }
  })();
  return prepared;
}

const timeout = (ms: number) => new Promise<false>(resolve => setTimeout(() => resolve(false), ms));

/**
 * Mostra o intersticial e só resolve quando o usuário fecha.
 * Se o anúncio não carregar a tempo (sem inventário), libera sem anúncio.
 */
export async function showInterstitial(): Promise<void> {
  if (!native) return;
  const ok = await Promise.race([preloadInterstitial(), timeout(ADMOB.loadTimeoutMs)]);
  prepared = null;
  if (!ok) { preloadInterstitial(); return; }

  try {
    await new Promise<void>((resolve, reject) => {
      const handles = [
        AdMob.addListener(InterstitialAdPluginEvents.Dismissed, () => done()),
        AdMob.addListener(InterstitialAdPluginEvents.FailedToShow, () => done()),
      ];
      const done = () => {
        handles.forEach(h => h.then(x => x.remove()));
        resolve();
      };
      AdMob.showInterstitial().catch(reject);
    });
  } catch (e) {
    console.warn('[ads] interstitial', e);
  } finally {
    preloadInterstitial();
  }
}
