# Changelog

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

## [0.3.0] - 2026-10-22

### À savoir

- **Mise à jour nécessaire** : une fois la 0.3.0 publiée, la connexion par pseudo et la recherche d'amis ne fonctionnent plus avec la version 0.2.4. Mettre à jour l'app

### Nouvelles fonctionnalités

- **Partager vers Wishy** : Un lien ou une image partagé depuis une autre app (Safari, Amazon, Photos…) ouvre la création d'un souhait, préremplie avec le nom, le lien et l'image ; avec plusieurs wishlists, on choisit d'abord la wishlist. Coller un lien dans le formulaire va aussi chercher son titre et son image
- **Recadrage des images** de souhait
- **Souhaits reçus** : Le propriétaire marque un souhait comme reçu, la quantité restante à offrir en tient compte et les souhaits reçus ont leur écran (Réglages). Supprimer une wishlist qui contient des souhaits reçus conserve ces souhaits
- **Liens de partage en https** : Une wishlist se partage avec un lien `https://wishy-app.fr/w/<id>`, cliquable dans les messageries, qui ouvre la wishlist dans l'app si elle est installée, sinon une page qui propose d'ouvrir l'app ou de découvrir Wishy
- **Erreurs de chargement expliquées** : Les écrans qui ne chargent pas affichent la cause (réseau, serveur), un bouton « Réessayer » et un bouton retour, au lieu d'une liste vide ou d'un chargement sans fin
- **Nouvelles illustrations**, une par état vide
- **Noms de souhait plus longs** : jusqu'à 80 caractères (50 auparavant), avec un compteur qui apparaît à l'approche de la limite
- **Recherche d'amis** par pseudo (2 caractères au moins, pseudo exact en premier) ou par email complet ; la recherche par morceau d'email n'existe plus
- **Mises à jour signalées** : quand une version plus récente est recommandée, une popup le propose à l'ouverture ; quand la version installée n'est plus prise en charge, un écran demande de mettre à jour avant de continuer
- **Remontée des plantages** (Sentry) dans les builds de release

### Sécurité

- Accès aux données restreints côté serveur : wishlists privées, réservations, souhaits reçus, profils et amitiés ne sont lisibles ou modifiables que par les personnes concernées, et seul le propriétaire d'une image peut la modifier ou la supprimer
- Les adresses email ne sont plus exposées dans les profils ni dans la recherche d'amis, et un utilisateur déconnecté ne peut plus que se connecter
- Le serveur refuse une réservation au-delà de la quantité restante (souhaits reçus compris, même en cas de réservations simultanées) ou dans une wishlist archivée, et la quantité d'un souhait ne peut plus descendre sous le total réservé
- Le service d'aperçu des liens n'accepte plus que les utilisateurs connectés et les adresses publiques

### Corrections de bugs

- Une erreur réseau à la connexion n'est plus présentée comme un mauvais mot de passe
- Les mots de passe sont envoyés tels que saisis sur tous les écrans d'authentification
- Les données affichées restent cohérentes pendant les rechargements temps réel (plus de souhait supprimé qui réapparaît, plus de liste d'amis qui reste en chargement sur un second écran)
- Après une déconnexion puis une connexion avec un autre compte, plus aucune donnée du compte précédent (wishlists, réservations, amis, avatar) n'est affichée
- Une erreur n'affiche plus une série de messages à la suite (ajout d'ami, changement de pseudo)
- Le bouton d'ouverture du lien d'un souhait n'apparaît que si le lien est valide
- Les erreurs des actions sur les wishlists et les amitiés sont affichées
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