# lib/ — Código-fonte do app Atos 29

Esta pasta contém todo o código Dart/Flutter do **Atos 29**, um aplicativo católico de comunidade com feed social, jornada de oração (novenas, terço, Lectio Divina, exame de consciência), liturgia diária, santo do dia e agenda de eventos. O backend é o **Firebase** (Auth, Firestore, Storage, Cloud Functions, Messaging e App Check).

> O repositório contém apenas a pasta `lib/`. Para rodar o projeto é necessário o restante do app Flutter (`pubspec.yaml`, `android/`, `ios/` etc.), que não está incluído aqui.

## Estrutura

```
lib/
├── main.dart                      # Ponto de entrada, tema, rotas e gates de inicialização
├── firebase_options.dart          # Configuração do Firebase por plataforma (gerada pelo FlutterFire)
├── core/                          # Serviços transversais (sem UI)
│   ├── admin/
│   │   └── admin_service.dart     # Ações de moderação com registro de auditoria
│   ├── auth/
│   │   └── admin_guard.dart       # Verificação de papel (role) do usuário
│   └── notifications/
│       ├── notification_service.dart   # Push (FCM): permissões, handlers, toque na notificação
│       └── novena_sync_service.dart    # Sincroniza o estado da novena local com o Firestore
└── modules/
    ├── admin/
    │   └── admin_notifications_page.dart   # Painel para enviar notificações por tópico
    ├── main/
    │   ├── screens/               # Telas do app (autenticação, feed, jornada, perfil etc.)
    │   └── services/
    │       └── user_profile_service.dart   # Criação e garantia do perfil no Firestore
    └── onboarding/
        └── screens/               # Telas de login e cadastro do fluxo de onboarding
```

## Fluxo de inicialização (`main.dart`)

1. Inicializa a formatação de datas em `pt_BR` e o Firebase.
2. Ativa o **App Check** e o **NotificationService** com timeout/try-catch, para que falhas não travem a abertura do app.
3. `StartupSplashGate` exibe a splash (`AtosSplashPage`) por um curto período.
4. `AuthFlowGate` decide o destino conforme o estado do usuário:
   - sem login → `LoginPage`;
   - e-mail não verificado → `VerifyEmailPage`;
   - verificado → `HomeGate`, que garante o perfil e abre a `MainScreen`.
5. A `MainScreen` usa uma barra de navegação inferior com **Feed**, **Santo**, **Agenda** e **Perfil**, e faz pré-carregamento de dados (`AppPrefetch`).

O app é fixado em português do Brasil e usa Material 3 com a paleta vinho (`#4E0405`), branco e preto.

## `core/`

| Arquivo | Responsabilidade |
|---|---|
| `admin/admin_service.dart` | Banir/desbanir usuário, restringir/restaurar permissão de postar e excluir post (soft delete). Cada ação grava um registro na coleção `audit_logs`. |
| `auth/admin_guard.dart` | Lê o campo `role` do usuário (`user`, `moderator`, `admin`, `owner`) e expõe `isAdminOrMod()` e `isOwner()`. |
| `notifications/notification_service.dart` | Pede permissão de notificação, registra o handler de mensagens em segundo plano e trata o toque em notificações (inclusive quando o app é aberto por elas). |
| `notifications/novena_sync_service.dart` | Copia o estado da novena ativa (guardado em `SharedPreferences`) para `users/{uid}.novena`, permitindo lembretes personalizados. |

## `modules/main/screens/`

**Autenticação e conta**
- `login_page.dart`, `register_page.dart`, `forgot_password_page.dart`, `verify_email_page.dart`
- `editar_perfil_page.dart` — edição de nome, apelido, bio e foto
- `menu_page.dart` — menu geral, Catecismo e exclusão de conta

**Comunidade**
- `feed_page.dart` — feed de posts com texto, fotos, enquetes e galeria em tela cheia
- `feed_post_actions_page.dart` — ações sobre posts (incluindo upload de imagens ao Storage)
- `share_post_card.dart`, `instagram_stories_share.dart` — geração de cartão e compartilhamento nos Stories
- `community_wall_editor_page.dart` — edição do mural da comunidade
- `notification_page.dart` — central de notificações
- `users_list_page.dart` — lista de usuários e ações administrativas (promover, remover papel, excluir, banir)

**Vida de oração**
- `home_page.dart` — tela inicial com cartão da jornada e avisos
- `jornada_page.dart` — jornada diária: novena ativa, missão do dia, Lectio Divina e exame de consciência
- `novena_page.dart`, `terco_page.dart`, `oracoes_page.dart`, `pedidos_oracoes.dart`
- `lectio_page.dart` — fluxo guiado de Lectio Divina com temporizador de silêncio
- `exame_consciencia_page.dart`
- `liturgia_page.dart` — liturgia diária
- `santo_page.dart` — santo do dia

**Institucional**
- `atos29_page.dart`, `estatuto_page.dart`, `sobre_app_page.dart`, `legal_page.dart`
- `calendario_page.dart` — agenda com eventos cadastrados pelos administradores

## Integrações externas

**Firebase**
- Auth (e-mail/senha e Google Sign-In), Firestore, Storage, Messaging, App Check
- Cloud Functions chamadas pelo app: `notifyPost`, `adminSendByTopic`, `adminDeleteAccount`, `adminDeleteAndBan`, `promoteUserToAdmin`, `removeUserAdminRole`

**Coleções do Firestore usadas**
`users`, `posts`, `community_wall`, `community_wall_topics`, `events`, `notifications`, `notification_reads`, `daily_missions`, `settings`, `audit_logs`

**APIs HTTP**
- Liturgia: `liturgia.up.railway.app`
- Santo do dia: `catolicoapp.com/wp-json/wp/v2/santos`
- Novenas: `novena-api.onrender.com`
- Orações: `oracoes-api.onrender.com`
- Missões diárias: `missions-api.onrender.com`
- Versículo do dia: `bibliaon.com`
- Catecismo: `vatican.va`

## Papéis e moderação

O campo `role` em `users/{uid}` define as permissões: `user`, `moderator`, `admin` e `owner`. O perfil é criado com padrões seguros (`role: user`, `canPost: true`, `status: active`) por `UserProfileService.ensureProfileCreated`, que também gera um apelido único. Ações de moderação passam pelo `AdminService` e ficam registradas em `audit_logs`.

## Observações

- Os pacotes principais usados são `firebase_*`, `cloud_functions`, `http`/`dio`, `shared_preferences`, `table_calendar`, `share_plus`, `image_picker`/`image_cropper`, `syncfusion_flutter_pdfviewer` e `webview_flutter`.
- Existem telas de login e cadastro duplicadas em `modules/main/screens/` e em `modules/onboarding/screens/`. O fluxo ativo em `main.dart` usa as de `main`; as de `onboarding` parecem ser uma versão alternativa.
- O `App Check` está configurado com provedores de **debug** em `main.dart`. Troque pelos provedores de produção (Play Integrity / App Attest) antes de publicar.
