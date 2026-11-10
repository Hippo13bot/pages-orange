# Pages orange — application de bureau Mac et Windows

Pages orange est un carnet de relations professionnelles. Le dépôt contient une version web et une application de bureau Electron.

## Construire les applications automatiquement avec GitHub

Le workflow `.github/workflows/desktop.yml` construit les deux installateurs sur les runners GitHub :
- macOS universel (Apple Silicon et Intel) : fichier `.dmg` et `.zip`
- Windows 64 bits : installateur `.exe`

### Première publication
1. Créer un dépôt GitHub **pages-orange**.
2. Envoyer le contenu de ce dossier à la racine du dépôt, sur la branche `main`.
3. Ouvrir l'onglet **Actions** et autoriser les workflows si GitHub le demande.
4. Le workflow **Build Pages orange desktop apps** démarre automatiquement.
5. Ouvrir l'exécution terminée et télécharger les artefacts `Pages-orange-mac` et `Pages-orange-windows`.

### Créer une version téléchargeable permanente
Créer et pousser un tag, par exemple `v1.0.0`. Le workflow joint alors les installateurs à une Release GitHub.

## Installation

### macOS
1. Télécharger le `.dmg`, l'ouvrir et glisser Pages orange dans Applications.
2. Au premier lancement, macOS peut signaler que l'application provient d'un développeur non identifié : les versions ne sont pas encore signées/notarisées.
3. Dans ce cas, ouvrir Réglages Système > Confidentialité et sécurité, puis choisir **Ouvrir quand même** si macOS propose cette option. Ne contourner l'avertissement que si le fichier provient bien de la Release officielle de votre dépôt.
4. Une signature Developer ID et la notarisation Apple nécessitent un compte Apple Developer et des certificats/secrets GitHub.

### Windows
1. Télécharger le fichier `.exe`.
2. Lancer l'installateur et suivre les étapes.
3. Windows SmartScreen peut afficher un avertissement tant que l'application n'a pas de certificat de signature éditeur.

## Développement local
```bash
npm install
npm start
```

## Fonctionnalités disponibles dans cette V1
- Tableau de bord.
- Fiches contacts avec coordonnées, métiers, entreprise, réseaux, tags, priorité et notes.
- Recherche, tri et filtre par tags.
- Entreprises, projets et relances locales.
- Import de captures multiples avec OCR Tesseract.js français/anglais dans le navigateur.
- Extraction prudente d'e-mails, téléphones et pseudonymes `@`, puis validation manuelle.
- Import CSV, vCard et sauvegardes JSON.
- Exports CSV, vCard, JSON et impression PDF.

## Limites actuelles — à ne pas confondre avec la publication desktop
- Les données sont stockées localement sur chaque appareil. Installer l'application sur Mac et Windows ne crée pas de synchronisation entre les deux.
- La synchronisation multi-appareils, les comptes d'équipe et Supabase ne sont pas encore connectés.
- L'OCR s'exécute dans l'application, mais Tesseract.js et ses modèles sont téléchargés depuis un CDN lors du premier usage.
- Les connecteurs Gmail, Instagram, WhatsApp et SMS ne sont pas actifs.
- Notion bidirectionnel et l'analyse IA locale avancée restent à développer.
- Ne jamais mettre de clé secrète dans le JavaScript client.

## GitHub Pages
Le workflow `.github/workflows/pages.yml` peut également publier la version web. Dans GitHub > Settings > Pages, choisir **GitHub Actions**.

## Refonte interface et identité visuelle (V2)

- Navigation principale simplifiée en cinq entrées : Accueil, Contacts, Échanges, Projets et Outils.
- Les entreprises restent accessibles depuis Contacts ; les relances depuis Accueil ; les paramètres depuis Outils.
- Le GIF fourni est conservé comme mascotte animée dans l'interface (`assets/dog.gif`).
- Les icônes natives Mac et Windows sont générées à partir de la première image du GIF (`assets/icon.icns` et `assets/icon.ico`). Les icônes système des deux plateformes sont statiques ; l'animation reste visible dans l'application.
- Les scripts de compilation utilisent `--publish never` afin que l'envoi des installateurs soit géré uniquement par GitHub Actions.

Icône native : image fixe extraite du GIF fourni, cadrée pour remplir toute la surface de l’icône (sans vignette blanche). Le GIF animé reste disponible séparément dans `assets/dog.gif`.

## Synchronisation Supabase (V2)

La synchronisation cloud est optionnelle et reste inactive tant que l'utilisateur n'a pas configuré son projet Supabase et ouvert une session.

1. Dans Supabase, exécuter `supabase/schema.sql` si le schéma initial n'a pas encore été installé.
2. Exécuter ensuite `supabase/migrations/20261108_pages_orange_sync.sql` dans le SQL Editor.
3. Dans Supabase > Project Settings > API, récupérer l'URL du projet et la clé publique `anon` ou `publishable` (jamais `service_role` / `secret`).
4. Dans Pages orange > Outils > Synchronisation cloud, saisir l'URL et la clé, puis enregistrer.
5. Créer un compte avec une adresse e-mail et un mot de passe. Si la confirmation par e-mail est activée, confirmer l'adresse puis revenir se connecter.

La première connexion fusionne les enregistrements locaux et distants par identifiant, puis envoie l'état fusionné. Les changements ultérieurs sont synchronisés automatiquement et les mises à jour reçues par Realtime sont répercutées sur les autres appareils. Les images sources et le texte OCR détaillé des captures ne sont pas téléversés : l’analyse et les extraits OCR restent locaux. Cette première version synchronise l'état applicatif dans une ligne JSONB par espace ; les invitations et rôles d'équipe ne sont pas encore proposés dans l'interface.

La clé publique est conservée dans le stockage local de l'appareil. L'accès aux données est protégé par RLS et la fonction de création d'espace. Ne jamais placer une clé `service_role` dans l'application.


## Connexions simplifiées et interface sombre (v1.2)

- Interface sombre sur l’ensemble de l’application, y compris les fenêtres et les formulaires.
- Page « Connexions » : un parcours en trois étapes pour le téléphone, WhatsApp/Instagram et la synchronisation multi-appareils.
- Sur certains navigateurs Android, « Choisir mes contacts » ouvre le sélecteur système. Sélectionnez plusieurs personnes et validez : les fiches sont ajoutées automatiquement.
- Sur iPhone avec Safari, l’accès direct au carnet n’est pas fourni par le navigateur. Dans Contacts, exportez une liste au format vCard (.vcf), enregistrez-la dans Fichiers, puis importez-la dans Pages Orange. Les fiches sont ajoutées automatiquement à partir du fichier.
- Pour WhatsApp et Instagram, partagez un profil ou copiez ses coordonnées, puis collez-les dans la page Connexions. Pages Orange prépare la fiche ; vous la vérifiez avant de l’ajouter. L’application ne lit pas les messages privés en arrière-plan.
- Les doublons sont filtrés sur l’e-mail, le téléphone, le pseudo Instagram et le nom complet.
- La synchronisation Supabase existante prend ensuite le relais si le compte cloud est connecté.
- Pour installer l’icône sur iPhone : ouvrir le site dans Safari, toucher Partager, choisir « Sur l’écran d’accueil », activer « Ouvrir comme app web » si proposé, puis toucher Ajouter. Le manifeste PWA et l’icône Apple Touch dédiée sont inclus.
