# Changelog

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

## [0.3.0] - 2026-10-22

### Nouvelles fonctionnalités

- **Partager vers Wishy** : Un lien ou une image partagé depuis une autre app (Safari, Amazon, Photos…) ouvre la création d'un souhait, préremplie avec le nom, le lien et l'image
- **Recadrage des images** de souhait
- **Souhaits reçus** : Le propriétaire marque un souhait comme reçu, la quantité restante à offrir en tient compte et les souhaits reçus ont leur écran
- **Liens de partage en https** : Une wishlist se partage avec un lien `https://wishy-app.fr/w/<id>`, cliquable dans toutes les messageries, qui ouvre l'app (App Links / Universal Links) ou une page web sinon
- **Erreurs de chargement expliquées** : Les écrans qui ne chargent pas affichent la cause (réseau, serveur), un bouton « Réessayer » et un bouton retour, au lieu d'une liste vide ou d'un chargement sans fin
- **Nouvelles illustrations**, une par état vide
- **Compteur de caractères** sur le nom d'un souhait (80 au plus)
- **Remontée des plantages** (Sentry) dans les builds de release

### Sécurité

- Accès aux données restreints côté serveur (policies Supabase) : wishlists privées, réservations, souhaits reçus, profils, amitiés et images ne sont lisibles ou modifiables que par les personnes concernées
- Réservation refusée par le serveur dans une wishlist archivée ou au-delà de la quantité restante
- Mots de passe de 8 caractères au moins, et connexion récente exigée pour les changer
- Aperçu des liens limité aux utilisateurs connectés et aux sites publics

### Corrections de bugs

- Une erreur réseau à la connexion n'est plus présentée comme un mauvais mot de passe
- Les mots de passe sont envoyés tels que saisis sur tous les écrans d'authentification
- Les données affichées restent cohérentes pendant les rechargements temps réel (plus de souhait supprimé qui réapparaît, de liste qui reste en chargement sur un second écran)
- Les actions d'un souhait qui dépendent de la quantité reçue sont masquées tant qu'elle n'est pas connue
- Un lien vers un souhait s'ouvre correctement, même sans la liste des souhaits voisins
- Le bouton d'ouverture du lien d'un souhait n'apparaît que si le lien est valide
- Les erreurs des actions sur les wishlists et les amitiés sont affichées
- L'utilisateur courant est suivi correctement d'une session à l'autre
- Fond prolongé sous la barre système en bas de la fiche d'un souhait et de la wishlist
- Les mots longs d'un titre de wishlist ne sont plus coupés

### Performances

- Images réseau décodées une seule fois
- L'écran d'une wishlist ne se reconstruit que sur ce qu'il affiche
- Index sur les clés étrangères utilisées par les requêtes et les policies, canaux temps réel filtrés par utilisateur

### CI/CD

- Migrations Supabase versionnées, validées et rejouées en CI, déployées sur dev au merge et sur prod au tag ; Edge Functions déployées de la même façon
- La CD vérifie l'analyse, les tests et la version du tag avant de déployer
- Version de Flutter figée depuis `pubspec.yaml` dans tous les workflows
- Fichiers d'environnement chiffrés (transcrypt)

## [0.2.4] - 2026-09-12

### CI/CD

- Version de Flutter (3.41.4) réellement figée dans la CI et la CD

## [0.2.3] - 2026-05-17

### Nouvelles fonctionnalités

- **Partage de wishlist** : Bouton de partage d'une wishlist (wishlists publiques) par lien profond, avec redirection vers la wishlist après connexion
- **Tri des amis en commun** : Les amis en commun sont triés par pseudo

### CI/CD

- Mise à jour automatique des golden files dans la CI
- Build iOS avec le SDK iOS 26 (runner macOS 26)
- Tentative de mise à jour de Flutter en 3.41.4, non effective (voir 0.2.4), et mise à jour du plugin Gradle Android (8.9.1)

### Corrections de bugs

- Messages d'erreur plus précis (par exemple lorsqu'un texte saisi est trop long)
- Le bouton retour du système quitte désormais le mode sélection au lieu de fermer la wishlist

## [0.2.2] - 2026-02-09

### Nouvelles fonctionnalités

- **Déplacement de souhaits** : Possibilité de déplacer des souhaits entre wishlists avec tri alphabétique et présélection de la wishlist récente
- **Avatars sur les cartes de souhaits** : Affichage des avatars des utilisateurs ayant réservé un souhait
- **Badge de notifications** : Indicateur visuel pour les demandes d'amis en attente sur la barre de navigation
- **Tri alphabétique des amis**

### CI/CD

- Mise en place de l'intégration continue (CI) GitHub Actions
- Mise en place du déploiement continu (CD) vers Google Play et TestFlight
- Ajout de golden tests pour tous les écrans

### Corrections de bugs

- Gestion améliorée du SafeArea et du padding bottom sur iOS
- Correction du padding dans FriendDetailsScreen
- Tri des souhaits réservés par favoris puis alphabétiquement
- Suppression du snackbar de confirmation à la création de souhait
- Amélioration du padding sur les titres des cartes de souhaits