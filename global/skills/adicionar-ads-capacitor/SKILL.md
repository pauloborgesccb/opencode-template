---
name: Adicionar ads (AdMob em Capacitor)
description: Adiciona monetização por anúncios (Google AdMob, banner + intersticial) em apps Ionic/Capacitor no padrão Contrictor validado no AoVivinho, com builds dev (anúncios de teste) e prod (reais) separados por env. Use quando pedirem para adicionar anúncios, ads ou AdMob em um app Capacitor, ou monetizar um app dessa arquitetura.
---

# Adicionar ads (AdMob) em app Capacitor (padrão Contrictor)

Resultado: banner + intersticial do AdMob funcionando, com `pnpm android:dev`/`ios:dev` servindo anúncios de TESTE e `*:prod` servindo anúncios REAIS, trocados por env do Vite. Quem for premium (se o app tiver assinatura) não vê anúncio.

Guia narrativo (parte negocial: conta, pagamentos, prazos, banimento): `contrictor/docs-uteis/README-ADS.md`. Referência viva: repo `contrictor/fake-live`.

## Passo a passo (agente)

0. Pergunte primeiro: "Quer que eu crie o app e os blocos na conta AdMob usando o BrowserOS neo? Só precisa estar logado no Google." Se sim, siga o "Modo automático via BrowserOS" abaixo; se não, peça os 2 App IDs (`ca-app-pub-...~...`) e os 4 unit IDs (`ca-app-pub-.../...`) de banner e intersticial por plataforma.
1. Dependência: `pnpm add @capacitor-community/admob` (com pnpm 11+, resolva o `allowBuilds` no `pnpm-workspace.yaml` se o install reclamar).
2. Config central: adicione o bloco de `templates/config-admob.ts` ao config do app, trocando os placeholders pelos unit IDs. Crie `.env.development` com `VITE_ADMOB_TESTING=true` e `.env.production` com `VITE_ADMOB_TESTING=false`.
3. Scripts no `package.json` (o ponto é nunca depender de memória para trocar teste/real):
   - `"build:dev": "tsc && vite build --mode development"` e `"build:prod": "tsc && vite build --mode production"`
   - `"android:dev"`/`"android:prod"` e `"ios:dev"`/`"ios:prod"`: build correspondente + `npx cap sync` + `npx cap open`.
4. Android: aplique `templates/android-manifest-snippet.xml` no `AndroidManifest.xml` com o App ID Android. Sem o meta-data o app abre e fecha (crash do SDK).
5. iOS: aplique `templates/ios-info-plist-snippet.xml` no `Info.plist` com o App ID iOS.
6. Serviço: copie `templates/ads.ts` para `src/services/ads.ts`. Pontos que não podem ser "simplificados" (cada um custou debug real):
   - `initialize` uma única vez com promise memoizada e `initializeForTesting: ADMOB.testing`.
   - Consentimento (UMP) e ATT num try/catch PRÓPRIO: se a conta não tiver formulário GDPR configurado, `requestConsentInfo` lança erro e isso NÃO pode abortar o init, senão nenhum anúncio carrega nunca.
   - Intersticial com timeout (`Promise.race` com `loadTimeoutMs`): sem inventário o fluxo do app segue em vez de travar.
   - No navegador (`!Capacitor.isNativePlatform()`) tudo vira no-op.
7. Uso nas páginas (copie o padrão do fake-live `src/pages/Home.tsx`):
   - Banner: `showBanner()` ao entrar na tela, `removeBanner()` ao sair; se houver premium, condicione a `!isPremium` e remova o banner quando o usuário virar premium.
   - Intersticial: `preloadInterstitial()` cedo (ex: no mount) e `await showInterstitial()` no gate (ex: antes de entrar na funcionalidade principal).
8. Teste no emulador (sem abrir IDE): build dev, `cap sync`, `./gradlew assembleDebug`, `adb install`, e `adb logcat | grep -iE "AdMob|Ads|FATAL"`. Sucesso = banner "Test Ad" na tela e `prepareInterstitial` sem erro.

## Modo automático via BrowserOS (conta AdMob)

Com o usuário logado no Google, em `apps.admob.com`:
1. Apps > Adicionar app, uma vez para Android e uma para iOS (se ainda não publicado: "Não" para loja). Capture o App ID (`~`).
2. Em cada app, criar 2 blocos: Banner e Intersticial. Capture os unit IDs (`/`). Dica: após criar, `grep` por `ca-app-pub` na página de confirmação retorna App ID + unit ID juntos.
3. Avise o usuário dos gates de conta que são dele: aprovação da conta, verificação de endereço por PIN (carta física) e, após publicar, vincular o app à listagem da loja. Nada disso é código: sem eles o Google responde `Account not approved yet (code 3)` e nenhum anúncio (nem de teste) aparece.
4. `app-ads.txt` no site do desenvolvedor (mesmo domínio informado na ficha da loja): linha `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`. Necessário para a verificação do app no AdMob.

## Troubleshooting

| Sintoma | Causa | Correção |
|---|---|---|
| App abre e fecha na hora | Falta `APPLICATION_ID`/`GADApplicationIdentifier` | Passos 4 e 5 |
| `requestConsentInfo ... no form(s) configured` | Conta sem mensagem GDPR | AdMob > Privacidade e mensagens; o ads.ts já tolera o erro |
| `Account not approved yet (code 3)` | Conta AdMob em análise ou endereço não verificado | Gates de conta (usuário) |
| Anúncio não preenche logo após criar bloco | Bloco novo sem inventário | Aguardar algumas horas |
| Emulador trava o browser/console | Emulador consome a CPU dos renderers | Fechar o emulador antes de usar o console no browser |
