# 🏗️ Architecture Realtime - Best Practices

## 📋 Principe de séparation des responsabilités

L'architecture Realtime suit le principe **CQRS** (Command Query Responsibility Segregation) :

- **Queries (Lecture)** : `StreamProvider` qui écoute les changements Realtime
- **Commands (Écriture)** : `MutationsProvider` qui expose les mutations

```
┌─────────────────────────────────────────────────────────┐
│                       UI LAYER                           │
│                                                          │
│  • Lecture : ref.watch(realtimeProvider)                │
│  • Écriture : ref.read(xxxMutationProvider.notifier)... │
└──────────────┬──────────────────┬────────────────────────┘
               │                  │
        LECTURE│                  │ÉCRITURE
               │                  │
      ┌────────▼────────┐  ┌──────▼──────────────┐
      │ StreamProvider  │  │  MutationsProvider  │
      │   (Realtime)    │  │ (Mutation<T> mixin) │
      └────────┬────────┘  └──────┬──────────────┘
               │                  │
               │                  │
      ┌────────▼──────────────────▼─────────┐
      │     Repository / Service             │
      └──────────────┬───────────────────────┘
                     │
            ┌────────▼────────┐
            │ Supabase Backend│
            └─────────────────┘
```

---

## 🎯 Avantages de cette architecture

### ✅ Séparation claire des responsabilités
- **Lecture** : Les StreamProviders ne font que de la lecture
- **Écriture** : Les MutationsProviders ne font que des mutations
- Pas de confusion entre les deux

### ✅ Gestion automatique des états (loading, error, idle)
```dart
// Le package riverpod_community_mutation gère automatiquement :
// • AsyncUpdate.idle() : Au repos
// • AsyncUpdate.loading() : Pendant la mutation
// • AsyncUpdate.error() : En cas d'erreur
// • AsyncUpdate.success(value) : Succès
final mutationState = ref.watch(wishMutationsProvider);
```

### ✅ Testabilité
```dart
// Facile à mocker dans les tests
// class MockWishService extends Mock implements WishService {}
final mockService = MockWishService();
when(() => mockService.createWish(request)).thenAnswer((_) async => wish);
// puis override de wishServiceProvider (voir la section Tests)
```

### ✅ Type safety
```dart
// Les mutations sont typées et documentées
await ref.read(wishlistMutationsProvider.notifier)
    .create(request);  // ✅ Auto-complétion & Type-safe
```

### ✅ Convention pour les écritures
```dart
// Wishlists, wishs, wishs terminés, amitiés : via le provider de mutation
await ref.read(wishlistMutationsProvider.notifier).create(request);

// Ailleurs : appel direct au service (voir le tableau récapitulatif)
await ref.read(userServiceProvider).updateUserProfile(...);
```

---

## 📁 Structure des fichiers

Pour chaque entité (Wishlist, Wish, Friendship), on a le modèle ci-dessous. Les wishs terminés suivent la même idée dans `user_completed_wish/` (`user_completed_wish_stream_repository*.dart`, sans `*_streams_providers.dart`), lus via `completedWishesRealtimeProvider` et `completedWishesByUserRealtimeProvider` :

### 1. Stream Repository (Lecture Realtime)
```
lib/shared/infra/repositories/xxx/
├── xxx_stream_repository.dart              # Interface
├── supabase_xxx_stream_repository.dart     # Implémentation
├── xxx_stream_repository_provider.dart     # Provider du repository
└── xxx_streams_providers.dart              # StreamProviders pratiques (optionnel)
```

### 2. Mutations Provider (Écriture)
```
lib/shared/infra/
├── xxx_mutations_provider.dart             # Mutations provider
└── xxx_mutations_provider.g.dart           # Fichier généré par riverpod_generator
```

**Exemple** : `wish_mutations_provider.dart`
```dart
@riverpod
class WishMutations extends _$WishMutations with Mutation<void> {
  @override
  AsyncUpdate<void> build() => const AsyncUpdate.idle();

  Future<void> create(WishCreateRequest request) async {
    await mutateAsync(() async {
      final service = ref.read(wishServiceProvider);
      await service.createWish(request);
    });
  }

  Future<void> update(Wish wish) async {
    await mutateAsync(() async {
      final service = ref.read(wishServiceProvider);
      await service.updateWish(wish);
    });
  }

  Future<void> delete(int wishId, {String? iconUrl}) async {
    await mutateAsync(() async {
      final service = ref.read(wishServiceProvider);
      await service.deleteWish(wishId, iconUrl: iconUrl);
    });
  }
}
```

### 3. Realtime Provider (Combinaison lecture)
```
lib/shared/infra/
└── xxx_realtime_provider.dart              # StreamProvider qui combine streams
```

---

## 💻 Exemples d'utilisation

### Wishlists

#### Lecture (Affichage)
```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Lecture via StreamProvider Realtime
    final wishlists = ref.watch(wishlistsRealtimeProvider);

    return wishlists.when(
      data: (data) => WishlistsGrid(wishlists: data),
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Erreur: $error'),
    );
  }
}
```

#### Écriture (Mutation)
```dart
class CreateWishlistButton extends ConsumerWidget {
  final WishlistCreateRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        // ✅ Écriture via MutationProvider
        await ref
            .read(wishlistMutationsProvider.notifier)
            .create(request);

        // L'UI se met à jour automatiquement via Realtime ! ✨
        // ⚠️ WishlistMutations utilise `mutate` : cet await ne lève jamais
        // d'exception (voir "Gestion des erreurs")
      },
      child: const Text('Créer'),
    );
  }
}
```

### Wishs

#### Lecture + Écriture combinées
```dart
class WishlistScreen extends ConsumerWidget {
  final int wishlistId;

  Future<void> onFavoriteToggle(WidgetRef ref, Wish wish) async {
    final updatedWish = wish.copyWith(
      isFavourite: !wish.isFavourite,
    );

    // ✅ Mutation via MutationProvider
    await ref
        .read(wishMutationsProvider.notifier)
        .update(updatedWish);

    // L'UI se met à jour automatiquement via Realtime ! ✨
    // WishMutations utilise `mutateAsync` : entourer l'appel d'un try/catch
    // pour gérer l'erreur (voir "Gestion des erreurs")
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Lecture via StreamProvider
    final wishs = ref.watch(watchWishsFromWishlistProvider(wishlistId));

    return wishs.when(
      data: (data) => ListView(
        children: data.map((wish) => WishCard(
          wish: wish,
          onFavoriteTap: () => onFavoriteToggle(ref, wish),
        )).toList(),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Erreur: $error'),
    );
  }
}
```

### Friendships

#### Lecture
```dart
class FriendsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Lecture via StreamProvider Realtime
    final friendsData = ref.watch(friendshipsRealtimeProvider);

    return friendsData.when(
      data: (data) => FriendsList(
        friends: data.friends,
        pendingFriends: data.pendingFriends,
        requestedFriends: data.requestedFriends,
      ),
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Erreur: $error'),
    );
  }
}
```

#### Écriture
```dart
class AskFriendshipButton extends ConsumerStatefulWidget {
  final String userId;

  @override
  ConsumerState<AskFriendshipButton> createState() => 
      _AskFriendshipButtonState();
}

class _AskFriendshipButtonState extends ConsumerState<AskFriendshipButton> {
  Future<void> onPressed(FriendshipStatus status) async {
    if (status == FriendshipStatus.none) {
      // ✅ Mutation via MutationProvider
      await ref
          .read(friendshipMutationsProvider.notifier)
          .askFriendship(widget.userId);

      // La liste d'amis se met à jour automatiquement via Realtime ! ✨
      // (FriendshipMutations utilise `mutate` : pas d'exception ici, et un
      // état optimiste local ne pourrait pas être annulé en cas d'erreur.)
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(friendshipStatusProvider(widget.userId));
    final displayStatus = status.value;

    return ElevatedButton(
      onPressed: displayStatus == null ? null : () => onPressed(displayStatus),
      child: Text(displayStatus == FriendshipStatus.none 
          ? 'Ajouter' 
          : 'En attente'),
    );
  }
}
```

---

## 🔄 Flow complet d'une mutation

Prenons l'exemple de l'ajout d'un ami :

```
1. Utilisateur clique sur "Ajouter ami"
   │
   ├─> UI appelle : ref.read(friendshipMutationsProvider.notifier).askFriendship(userId)
   │
2. MutationProvider appelle mutate() (ou mutateAsync())
   │
   ├─> État passe à AsyncUpdate.loading()
   │
3. La mutation appelle le Service
   │
   ├─> FriendshipService.askFriendshipTo(userId)
   │
4. Service appelle le Repository
   │
   ├─> FriendshipRepository.askFriendshipTo(userId)
   │
5. Repository fait l'INSERT dans Supabase
   │
   ├─> INSERT INTO friendships (...)
   │
6. Supabase Realtime détecte le changement
   │
   ├─> WebSocket notification → INSERT event
   │
7. StreamRepository reçoit l'événement
   │
   ├─> SupabaseFriendshipStreamRepository.watchCurrentUserAllFriendships()
   │
8. StreamProvider émet les nouvelles données
   │
   ├─> friendshipsRealtimeProvider émet FriendsData mis à jour
   │
9. UI se rebuilds automatiquement
   │
   └─> ✨ Le nouvel ami apparaît dans la liste !
```

---

## 📊 Comparaison Avant / Après

### ❌ Avant (sans MutationProvider, ancien code)

```dart
// Appel direct au service depuis l'UI
await ref.read(friendshipServiceProvider).askFriendshipTo(userId);

// Problèmes :
// - Couplage fort entre UI et Service
// - Difficile à tester
// - Pas de séparation des responsabilités
// - Pas de gestion automatique de l'état loading/error
// - Moins lisible
```

### ✅ Après (avec MutationProvider)

```dart
// Appel via le provider de mutation
await ref
    .read(friendshipMutationsProvider.notifier)
    .askFriendship(userId);

// Avantages :
// ✅ Séparation claire (lecture vs écriture)
// ✅ Facilement mockable pour les tests
// ✅ API claire et documentée
// ✅ Gestion automatique des états (idle, loading, success, error)
// ✅ Plus maintenable et scalable
```

---

## 🎓 Règles à suivre

### ✅ À FAIRE

1. **Lecture** : Toujours utiliser les StreamProviders
```dart
final data = ref.watch(xxxRealtimeProvider);
```

2. **Écriture** : Toujours utiliser les MutationsProviders
```dart
await ref.read(xxxMutationProvider.notifier).action();
```

3. **Grouper les mutations CRUD dans une seule classe**
```dart
// ✅ BON : Une classe qui groupe create, update, delete
@riverpod
class WishMutations extends _$WishMutations with Mutation<void> {
  @override
  AsyncUpdate<void> build() => const AsyncUpdate.idle();

  Future<void> create(WishCreateRequest request) async { /* ... */ }
  Future<void> update(Wish wish) async { /* ... */ }
  Future<void> delete(int wishId, {String? iconUrl}) async { /* ... */ }
}
```

4. **Ne jamais invalider manuellement** les StreamProviders Realtime (sauf refresh explicite)
```dart
// ❌ PAS BESOIN de ça avec Realtime après une mutation !
// ref.invalidate(wishlistsRealtimeProvider);
// → Les données se mettent à jour automatiquement via Realtime
```

### ❌ À NE PAS FAIRE

1. **Éviter d'appeler le service directement pour les entités qui ont un provider de mutation** (wishlists, wishs, wishs terminés, amitiés)
```dart
// ❌ À ÉVITER
await ref.read(wishlistServiceProvider).createWishlist(...);

// ✅ BON
await ref.read(wishlistMutationsProvider.notifier).create(...);
```
Les entités sans provider de mutation (voir le tableau récapitulatif) passent par le service, et une écriture sur les wishlists contourne encore les mutations : `updateWishlistsOrder` (réordonnancement), appelé directement sur `wishlistServiceProvider` dans `wishlists_grid.dart`. (`getNextWishlistOrderByUser` dans `create_dialog.dart` est une lecture.)

2. **Ne jamais mélanger lecture et écriture dans le même provider**
```dart
// ❌ MAUVAIS : Un StateNotifier qui gère lecture ET écriture
class BadNotifier extends StateNotifier<AsyncValue<Data>> {
  Future<void> create() { /* mutation */ }
  Future<void> load() { /* lecture */ }
}
```

3. **Ne pas créer de StateNotifier pour les données Realtime**
```dart
// ❌ MAUVAIS : StateNotifier pour données Realtime
final badProvider = StateNotifierProvider<DataNotifier, AsyncValue<Data>>();

// ✅ BON : StreamProvider pour données Realtime
final goodProvider = StreamProvider<Data>();
```

4. **Ne pas créer plusieurs providers pour des mutations CRUD de la même entité**
```dart
// ❌ MAUVAIS : Provider séparé pour chaque action CRUD
@riverpod
class CreateWishMutation extends _$CreateWishMutation with Mutation<Wish> { }

@riverpod
class UpdateWishMutation extends _$UpdateWishMutation with Mutation<Wish> { }

@riverpod  
class DeleteWishMutation extends _$DeleteWishMutation with Mutation<void> { }

// ✅ BON : Une classe qui groupe toutes les mutations de l'entité
@riverpod
class WishMutations extends _$WishMutations with Mutation<void> {
  Future<void> create(WishCreateRequest request) { }
  Future<void> update(Wish wish) { }
  Future<void> delete(int wishId, {String? iconUrl}) { }
}
```

**Avantages** :
- API plus courte : `wishMutationsProvider.notifier.create()`
- Un seul provider par entité au lieu de 3
- État loading/error partagé (généralement suffisant avec Realtime)
- Plus cohérent et maintenable

---

## 🧪 Tests

Exemple de test d'une mutation (à adapter ; il n'existe pas encore de tests dédiés aux providers de mutation) :

```dart
// class MockWishService extends Mock implements WishService {}
// `request` : un WishCreateRequest, `wish` : un Wish (fixtures du test)
test('WishMutations.create appelle le service', () async {
  final mockService = MockWishService();
  final container = ProviderContainer(
    overrides: [wishServiceProvider.overrideWithValue(mockService)],
  );
  when(() => mockService.createWish(request)).thenAnswer((_) async => wish);

  await container.read(wishMutationsProvider.notifier).create(request);

  verify(() => mockService.createWish(request)).called(1);
  // Après un succès, l'état est AsyncUpdate.success(null), pas idle
});
```

---

## 📝 Checklist pour ajouter une nouvelle entité Realtime

### Étape 1 : Repositories (Lecture & Écriture classique)
- [ ] Créer l'interface `XxxRepository` (CRUD classique)
- [ ] Créer l'implémentation `SupabaseXxxRepository`
- [ ] Créer le provider `xxxRepositoryProvider`

### Étape 2 : Stream Repository (Lecture Realtime)
- [ ] Créer l'interface `XxxStreamRepository`
- [ ] Créer l'implémentation `SupabaseXxxStreamRepository`
  - [ ] Gérer les channels Realtime
  - [ ] Écouter les événements PostgreSQL (INSERT, UPDATE, DELETE)
  - [ ] Gérer le cleanup des streams
- [ ] Créer le provider `xxxStreamRepositoryProvider`
- [ ] (Optionnel) Créer les StreamProviders pratiques dans `xxxStreamsProviders`

### Étape 3 : Service
- [ ] Créer le `XxxService` qui utilise le repository classique
- [ ] Créer le provider `xxxServiceProvider`

### Étape 4 : Realtime Provider
- [ ] Créer le `xxxRealtimeProvider` (StreamProvider)
- [ ] Combiner les streams nécessaires
- [ ] Charger les données liées si nécessaire

### Étape 5 : Mutations Provider
- [ ] Créer `xxx_mutations_provider.dart` avec une classe `XxxMutations`
  - [ ] Méthode `create()` (si applicable)
  - [ ] Méthode `update()` (si applicable)
  - [ ] Méthode `delete()` (si applicable)
- [ ] Générer le code : `dart run build_runner build --delete-conflicting-outputs`

### Étape 6 : Migration UI
- [ ] Migrer les widgets pour utiliser `xxxRealtimeProvider` (lecture)
- [ ] Migrer les widgets pour utiliser `xxxMutationsProvider.notifier.create/update/delete()` (écriture)
- [ ] Supprimer les anciens `ref.invalidate()` (plus nécessaires après mutations !)
- [ ] Ajouter la gestion d'erreur : utiliser `mutateAsync` dans le provider et entourer l'appel d'un `try/catch` (voir "Gestion des erreurs")

### Étape 7 : Tests
- [ ] Tester la synchronisation Realtime sur plusieurs appareils
- [ ] Tester les mutations (create, update, delete)
- [ ] Vérifier que l'UI se met à jour automatiquement
- [ ] Tests unitaires des mutations

---

## 🎉 Résumé

### Architecture actuelle

| Entité | Lecture (StreamProvider) | Écriture (MutationsProvider) |
|--------|-------------------------|------------------------------|
| **Wishlists** | `wishlistsRealtimeProvider` | `wishlistMutationsProvider`<br>→ `.create(request)`<br>→ `.update(wishlist)`<br>→ `.delete(id)` |
| **Wishs** | `watchWishsFromWishlistProvider` | `wishMutationsProvider`<br>→ `.create(request)` / `.createWithImage(...)`<br>→ `.update(wish)` / `.updateWithImage(...)`<br>→ `.delete(id, {iconUrl})`<br>→ `.moveToWishlist(...)` |
| **Wishs terminés** | `completedWishesRealtimeProvider`, `completedWishesByUserRealtimeProvider` | `completedWishMutationsProvider`<br>→ `.markAsCompleted(wish, {quantity})`<br>→ `.updateCompletedWishQuantity(...)`<br>→ `.unmarkAsCompleted(wishId)`<br>→ `.restoreCompletedWish(...)` |
| **Friendships** | `friendshipsRealtimeProvider` | `friendshipMutationsProvider`<br>→ `.askFriendship(userId)`<br>→ `.acceptFriendship(userId)`<br>→ `.declineFriendship(userId)`<br>→ `.cancelFriendshipRequest(userId)`<br>→ `.removeFriendship(userId)` |
| **Profiles** | `watchProfileByIdProvider` | *(écriture via `UserService`, pas de provider de mutation)* |

### Avantages obtenus

- ✅ Séparation claire lecture/écriture (CQRS)
- ✅ Écritures wishlists / wishs / wishs terminés / amitiés centralisées dans des providers de mutation
- ✅ Code plus testable et maintenable
- ✅ API claire et documentée
- ✅ Gestion automatique des états (idle, loading, success, error)
- ✅ Synchronisation automatique en temps réel
- ✅ Architecture scalable et cohérente
- ✅ Support des relations (JOIN) en Realtime
- ✅ Package communautaire maintenu (`riverpod_community_mutation`)

---

## 🔄 Gestion des états de mutations

Le package `riverpod_community_mutation` gère automatiquement les états de vos mutations via `AsyncUpdate<T>`.

### États disponibles

```dart
// État initial (au repos)
AsyncUpdate<T>.idle()

// État en cours de mutation
AsyncUpdate<T>.loading()

// État succès avec données
AsyncUpdate<T>.success(value)

// État erreur
AsyncUpdate<T>.error(error, stackTrace)
```

### Utilisation dans l'UI

#### Observer l'état d'une mutation

```dart
class CreateWishButton extends ConsumerWidget {
  final WishCreateRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observer l'état de la mutation
    final mutationState = ref.watch(wishMutationsProvider);

    return ElevatedButton(
      onPressed: mutationState.isLoading 
          ? null  // Désactiver pendant le chargement
          : () async {
              await ref
                  .read(wishMutationsProvider.notifier)
                  .create(request);
            },
      child: mutationState.isLoading
          ? const CircularProgressIndicator()
          : const Text('Créer'),
    );
  }
}
```

### Gestion des erreurs : `mutate` vs `mutateAsync`

Le mixin `Mutation` (`riverpod_community_mutation` 1.1.2, `mutation.dart`) propose deux méthodes :

- **`mutate(fn, {onSuccess, onError, onFinally})`** : attrape l'erreur, la met dans l'état (`AsyncUpdate.error`) et la logue, **sans la relancer**. Seul `onError` permet d'y réagir dans la méthode. Un `try/catch` autour de `await ...notifier.xxx()` ne s'exécute donc jamais.
- **`mutateAsync(fn)`** : met l'état à jour puis **relance** l'erreur : un `try/catch` côté UI fonctionne.

Dans le code actuel :

- `WishMutations` et `CompletedWishMutations` utilisent `mutateAsync` : un `try/catch` autour de l'appel fonctionne.
- `WishlistMutations` et `FriendshipMutations` utilisent encore `mutate` sans `onError`. **C'est un défaut connu, pas une convention** : l'erreur n'est visible que dans l'état, alors que les écrans (`wishlist_settings_bottom_sheet.dart`, `friend_details_app_bar.dart`, `ask_friendship_button.dart`) les entourent d'un `try/catch` qui ne s'exécute jamais. Par exemple, un `removeFriendship` qui échoue affiche quand même le message de succès. Le correctif est de les passer à `mutateAsync`, sans toucher aux écrans.

Pour les nouvelles mutations, utiliser `mutateAsync` et gérer l'erreur à l'endroit de l'appel :

```dart
try {
  await ref
      .read(completedWishMutationsProvider.notifier)
      .markAsCompleted(wish);
} catch (e) {
  if (mounted) showGenericError(context, error: e);
}
```

Éviter `ref.listen` sur un provider de mutation pour afficher un message : son état est partagé (ce ne sont pas des familles), donc le listener se déclenche aussi pour une mutation lancée par un autre widget, y compris plusieurs instances du même widget.

---

## 🔗 Gestion des relations (JOIN) en Realtime

### Problème : Tables liées par JOIN

Certaines données sont chargées via des JOIN SQL :
```sql
SELECT * FROM wishs 
LEFT JOIN wish_taken_by_user ON wishs.id = wish_taken_by_user.wish_id
```

**Problème** : Si `wish_taken_by_user` change, le stream des `wishs` doit se mettre à jour !

### Solution : Écouter plusieurs tables sur le même channel

```dart
final channel = _client
    .channel('wishs_wishlist_$wishlistId')
    // Écouter la table principale
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      table: 'wishs',
      filter: ...,
      callback: (payload) => _reloadData(),
    )
    // Écouter AUSSI la table liée
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      table: 'wish_taken_by_user',
      callback: (payload) => _reloadData(), // ← Même callback !
    )
    .subscribe();
```

**Résultat** : Quand quelqu'un réserve un wish (INSERT dans `wish_taken_by_user`), le stream des wishs se met à jour automatiquement avec les nouvelles réservations ! ✨

### Exemple concret

1. Alice ouvre la wishlist de Bob
2. Elle voit un wish "PS5" sans réservation
3. Charlie (sur un autre appareil) réserve la PS5
   - → INSERT dans `wish_taken_by_user`
4. Le stream d'Alice détecte le changement
5. Alice voit maintenant "PS5 (réservée par Charlie)" **en temps réel** !

---

## 📦 Dépendances

Cette architecture utilise les packages suivants :

- **`riverpod`** / **`flutter_riverpod`** : State management
- **`riverpod_annotation`** : Génération de code pour providers
- **`riverpod_community_mutation`** (^1.1.2) : Gestion des mutations avec états automatiques
- **`supabase_flutter`** : Client Supabase avec support Realtime

---

**Créé le** : 28 octobre 2025  
**Dernière mise à jour** : 17 octobre 2026 (gestion des erreurs `mutate` / `mutateAsync`, alignement sur le code)  
**Statut** : ✅ Implémenté et en production
Détail par entité (lecture et mutations) : voir le tableau de la section « Résumé ».

