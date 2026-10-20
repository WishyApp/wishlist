# Changelog

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

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