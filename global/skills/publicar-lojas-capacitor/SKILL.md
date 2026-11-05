---
name: Publicar lojas (Capacitor + fastlane + Actions)
description: Configura publicação automática nas lojas (Google Play faixa interna + TestFlight) em apps Ionic/Capacitor, no padrão Contrictor validado no AoVivinho; tag v* publica, push em branch não faz nada. Use quando pedirem para configurar deploy/publicação/CI de loja em um app Capacitor.
---

# Publicação automática nas lojas (padrão Contrictor)

Resultado: `git tag v1.0.0 && git push origin v1.0.0` builda e publica Android na faixa interna do Google Play e iOS no TestFlight. Push em branch não dispara nada. `versionName` = tag sem `v`; `versionCode` = número do run.

Guia narrativo completo (contas, telas, 10 erros resolvidos): `contrictor/docs-uteis/README-CI.md`. Referência viva: repo `contrictor/fake-live`.

## Passo a passo (agente)

1. Colete do usuário: bundle/package id, nome do repo de certificados iOS (ex: `certificados-ios`), org GitHub, Apple Team ID (sai do log do match ou da membership). Substitua `{{BUNDLE_ID}}`, `{{TEAM_ID}}`, `{{ORG}}`, `{{CERT_REPO}}` nos templates.
2. Base do repo: copie `templates/Gemfile` pra raiz; gere `Gemfile.lock` com Ruby 3.3 (rbenv: `rbenv local 3.3.x && bundle install`) e commite lockfile + `.ruby-version`. Garanta `.sdkmanrc` com Java 21 (Java 25 quebra Gradle 8.14) e, com pnpm 11+, `allowBuilds` resolvido no `pnpm-workspace.yaml`.
3. Android:
   - Keystore: `keytool -genkeypair -keystore android/upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`, senha gerada salva em `android/keystore.properties`. Padrão Contrictor: ambos versionados no repo privado.
   - `android/app/build.gradle`: signingConfig release lendo `keystore.properties` (envs `KEYSTORE_FILE/KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD` com precedência) e `versionCode`/`versionName` por env `VERSION_CODE`/`VERSION_NAME`. Copie o bloco do fake-live.
   - `android/fastlane/`: `templates/Fastfile.android` + `templates/Appfile.android`. App ainda não publicado exige `release_status: 'draft'`; depois da primeira publicação troque pra `'completed'`.
   - Valide local: `cd android && ./gradlew bundleRelease` e `jarsigner -verify` no AAB.
4. iOS:
   - `ios/App/fastlane/`: `templates/Fastfile.ios`, `templates/Appfile.ios`, `templates/Matchfile` (SSH + `git_branch('main')`; match assume master).
   - Capacitor 8 é SPM, sem CocoaPods: build por `project: 'App.xcodeproj'`. Scheme compartilhado obrigatório: copie `templates/App.xcscheme` pra `ios/App/App.xcodeproj/xcshareddata/xcschemes/` (BlueprintIdentifier `504EC303...` é o do template padrão do Capacitor; confira no `project.pbxproj`).
   - `Info.plist`: `ITSAppUsesNonExemptEncryption=false` (senão todo build trava no TestFlight em "Faltam dados de conformidade").
   - Deploy key: `ssh-keygen -t ed25519 -f docs/match_deploy_key -N ""`; pública como Deploy key (write) no repo de certificados; privada vira secret `MATCH_SSH_KEY`. Nunca use PAT fine-grained com resource owner pessoal em repo de org (dá 403).
   - Primeira execução do match com `readonly: false` (cria cert/profile); depois volte pra `readonly: is_ci`.
5. Workflows: copie `templates/android-release.yml` e `templates/ios-release.yml` pra `.github/workflows/`.
6. Gitignore + segredos: ignore `*.p8`, `*/play-store-key.json`, `docs/SECRETS.local.md`, `docs/match_deploy_key*`. Crie `docs/SECRETS.local.md` a partir de `templates/SECRETS.local.md.exemplo`; valores só lá e nos Secrets do GitHub (do repo do app, nunca de outro). O agente não cola credenciais: o usuário cria os secrets `PLAY_STORE_JSON_KEY`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `MATCH_PASSWORD`, `MATCH_SSH_KEY`.
7. Contas (uma vez por app, com o usuário):
   - Play: criar o app; service account no projeto GCP `contrictor` com a API "Google Play Android Developer" habilitada + chave JSON; convidar o e-mail no Play Console com as 4 permissões de release (sem isso: "The caller does not have permission"); primeiro AAB é upload manual.
   - Apple: bundle ID + app no App Store Connect; API key "Gerente de apps" (acesso só o Titular solicita; `.p8` baixa 1 vez); repo privado de certificados (só conteúdo criptografado do match, nunca o `.p8`).
8. Teste: tag `v0.0.1` (ou dispatch no iOS) e acompanhe os runs. Erros conhecidos: tabela "Erros já vividos" do README-CI.md.

## Pós-publicação

Tag → faixa interna/TestFlight é 100% automático. Promover pra produção é manual por design. Manutenção rara: cert Apple expira em ~1 ano (match com `readonly: false` renova); taxa anual Apple.
