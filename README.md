# 📖 Atos 29 — Código-fonte (`lib/`)

![Flutter](https://img.shields.io/badge/Flutter-Material%203-02569B?logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase&logoColor=black)
![Idioma](https://img.shields.io/badge/Idioma-pt--BR-009C3B)

O **Atos 29** é um aplicativo católico de comunidade. A ideia é reunir em um só lugar o que o fiel usa no dia a dia: um feed para compartilhar e conviver, uma jornada de oração com novenas, terço, Lectio Divina e exame de consciência, a liturgia diária, o santo do dia e uma agenda de eventos da comunidade.

Esta pasta guarda todo o código Dart/Flutter do app. O backend roda no **Firebase** (Auth, Firestore, Storage, Cloud Functions, Messaging e App Check), e alguns conteúdos vêm de APIs externas de liturgia, santos, novenas e orações.

> **Atenção:** o repositório contém apenas a pasta `lib/`. Para rodar o projeto é preciso o restante do app Flutter (`pubspec.yaml`, `android/`, `ios/` etc.), que não está incluído aqui.

## ✨ O que o app faz

- **Comunidade:** feed com texto, fotos e enquetes, mural da comunidade, notificações e compartilhamento de posts em cartões (inclusive nos Stories do Instagram).
- **Vida de oração:** jornada diária com missão do dia, novenas com acompanhamento de dias, Santo Terço interativo, Lectio Divina guiada com temporizador de silêncio, exame de consciência, biblioteca de orações e pedidos de oração.
- **Conteúdo diário:** liturgia do dia, santo do dia e versículo do dia.
- **Institucional:** agenda de eventos, estatuto, Catecismo, sobre o app e termos legais.
- **Administração:** moderação de usuários e posts, envio de notificações por tópico e gestão de papéis.

## 🗂️ Estrutura

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

A organização segue uma divisão simples: o que é **compartilhado e sem interface** fica em `core/`, e o que é **tela ou funcionalidade** fica em `modules/`, separado por área (`admin`, `main`, `onboarding`).

## 🚀 Fluxo de inicialização (`main.dart`)

1. Inicializa a formatação de datas em `pt_BR` e o Firebase.
2. Ativa o **App Check** e o **NotificationService** com timeout e `try/catch`, para que uma falha nessas etapas nunca trave a abertura do app.
3. `StartupSplashGate` exibe a splash (`AtosSplashPage`) por menos de um segundo.
4. `AuthFlowGate` decide o destino conforme o estado do usuário:
   - sem login → `LoginPage`;
   - e-mail não verificado → `VerifyEmailPage`;
   - verificado → `HomeGate`, que garante o perfil e abre a `MainScreen`.
5. A `MainScreen` usa uma barra de navegação inferior com **Feed**, **Santo**, **Agenda** e **Perfil**, e faz o pré-carregamento de dados em segundo plano (`AppPrefetch`).

O app é fixado em português do Brasil e usa Material 3 com a paleta vinho (`#4E0405`), branco e preto.

## 🧱 `core/`

| Arquivo | Responsabilidade |
|---|---|
| `admin/admin_service.dart` | Banir e desbanir usuário, restringir e restaurar a permissão de postar e excluir post (soft delete). Cada ação grava um registro na coleção `audit_logs`, o que deixa o histórico de moderação rastreável. |
| `auth/admin_guard.dart` | Lê o campo `role` do usuário (`user`, `moderator`, `admin`, `owner`) e expõe `isAdminOrMod()` e `isOwner()` para liberar ou bloquear telas e ações. |
| `notifications/notification_service.dart` | Pede permissão de notificação, registra o handler de mensagens em segundo plano e trata o toque em notificações, inclusive quando o app é aberto por elas. |
| `notifications/novena_sync_service.dart` | Copia o estado da novena ativa (guardado em `SharedPreferences`) para `users/{uid}.novena`, permitindo lembretes personalizados. |

## 📱 `modules/main/screens/`

**Autenticação e conta**
- `login_page.dart`, `register_page.dart`, `forgot_password_page.dart`, `verify_email_page.dart`
- `editar_perfil_page.dart` — edição de nome, apelido, bio e foto
- `menu_page.dart` — menu geral, Catecismo e exclusão de conta

**Comunidade**
- `feed_page.dart` — feed de posts com texto, fotos, enquetes e galeria em tela cheia
- `feed_post_actions_page.dart` — ações sobre posts, incluindo upload de imagens ao Storage
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

## 🔌 Integrações externas

**Firebase**
- Auth (e-mail e senha, além de Google Sign-In), Firestore, Storage, Messaging e App Check
- Cloud Functions chamadas pelo app: `notifyPost`, `adminSendByTopic`, `adminDeleteAccount`, `adminDeleteAndBan`, `promoteUserToAdmin` e `removeUserAdminRole`

**Coleções do Firestore**

`users`, `posts`, `community_wall`, `community_wall_topics`, `events`, `notifications`, `notification_reads`, `daily_missions`, `settings` e `audit_logs`

**APIs HTTP**

| Conteúdo | Origem |
|---|---|
| Liturgia | `liturgia.up.railway.app` |
| Santo do dia | `catolicoapp.com/wp-json/wp/v2/santos` |
| Novenas | `novena-api.onrender.com` |
| Orações | `oracoes-api.onrender.com` |
| Missões diárias | `missions-api.onrender.com` |
| Versículo do dia | `bibliaon.com` |
| Catecismo | `vatican.va` |

Como várias dessas APIs ficam em hospedagens gratuitas (Render e Railway), a primeira requisição depois de um tempo parado pode demorar.

## 🛡️ Papéis e moderação

O campo `role` em `users/{uid}` define as permissões:

| Papel | Descrição |
|---|---|
| `user` | Membro comum |
| `moderator` | Modera conteúdo e usuários |
| `admin` | Acesso administrativo |
| `owner` | Dono, com todos os poderes |

O perfil é criado com padrões seguros (`role: user`, `canPost: true`, `status: active`) por `UserProfileService.ensureProfileCreated`, que também gera um apelido único. Toda ação de moderação passa pelo `AdminService` e fica registrada em `audit_logs`.

## 🧩 Pacotes principais

`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `firebase_app_check`, `cloud_functions`, `google_sign_in`, `http`, `dio`, `shared_preferences`, `table_calendar`, `share_plus`, `image_picker`, `image_cropper`, `cached_network_image`, `syncfusion_flutter_pdfviewer` e `webview_flutter`.

## 📝 Notas para quem for mexer no código

- Existem telas de login e cadastro duplicadas em `modules/main/screens/` e em `modules/onboarding/screens/`. O fluxo ativo em `main.dart` usa as de `main`; as de `onboarding` parecem ser uma versão alternativa e podem ser consolidadas.
- O **App Check** está configurado com provedores de **debug** em `main.dart`. Troque pelos provedores de produção (Play Integrity no Android e App Attest no iOS) antes de publicar.
- As URLs das APIs estão escritas direto nas telas. Se o número de integrações crescer, vale centralizá-las em um arquivo de configuração dentro de `core/`.
- Novas ações de moderação devem passar pelo `AdminService`, para manter o registro em `audit_logs`.
