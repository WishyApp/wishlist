import { createClient } from 'npm:@supabase/supabase-js@2.45.0';
import { appleConfigFromEnv, appleUserIdOf, authorizationCodeOf, revokeAppleTokens } from './apple_revocation.ts';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
console.info('Delete user account function started');

async function revokeAppleAuthorization(authorizationCode: string | null, appleUserId: string | null) {
  if (!authorizationCode) {
    if (appleUserId) {
      console.warn('Apple revocation skipped: Apple account deleted without an authorization code');
    }
    return;
  }
  if (!appleUserId) {
    console.warn('Apple revocation skipped: authorization code sent for an account without an Apple identity');
    return;
  }
  const appleConfig = appleConfigFromEnv((name)=>Deno.env.get(name));
  if (!appleConfig) {
    console.error('Apple revocation skipped: APPLE_* secrets are missing');
    return;
  }
  try {
    const { belongsToAccount } = await revokeAppleTokens({
      config: appleConfig,
      authorizationCode,
      appleUserId
    });
    if (belongsToAccount) {
      console.info('Apple tokens revoked');
    } else {
      console.warn('Apple code from another Apple ID: that authorization is revoked, the deleted account\'s is not');
    }
  } catch (error) {
    console.error('Error revoking Apple tokens:', error);
  }
}
Deno.serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    // Créer un client Supabase avec les permissions admin
    const supabaseAdmin = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });
    // Récupérer l'utilisateur depuis le token JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing Authorization header');
    }
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user) {
      throw new Error('Unauthorized');
    }
    const userId = user.id;
    // Code d'autorisation Apple frais, envoyé par l'app pour un compte Apple :
    // la révocation a lieu une fois le compte supprimé (étape 6).
    const body = await req.json().catch(() => ({}));
    const appleAuthorizationCode = authorizationCodeOf(body);
    const appleUserId = appleUserIdOf(user.identities);
    // Lancer toutes les opérations en parallèle pour accélérer le processus
    // 1. Récupérer tous les wishes et l'avatar en parallèle
    const [wishesResult, profileResult] = await Promise.all([
      supabaseAdmin.from('wishs').select('id, icon_url, wishlists!inner(id_owner)').eq('wishlists.id_owner', userId),
      supabaseAdmin.from('profiles').select('avatar_url').eq('id', userId).single()
    ]);
    // 2. Collecter tous les chemins d'images à supprimer
    const imagePaths = [];
    if (!wishesResult.error && wishesResult.data && wishesResult.data.length > 0) {
      for (const wish of wishesResult.data){
        const iconUrl = wish.icon_url;
        if (iconUrl) {
          imagePaths.push(iconUrl);
          // Ajouter aussi le chemin de la miniature
          const thumbnailPath = iconUrl.replace('.webp', '_thumb.webp');
          imagePaths.push(thumbnailPath);
        }
      }
    }
    // 3. Préparer les promesses de suppression
    const deletePromises = [];
    // Supprimer toutes les images de wishes par lots en parallèle
    if (imagePaths.length > 0) {
      const batchSize = 100; // Limite de Supabase pour remove()
      for(let i = 0; i < imagePaths.length; i += batchSize){
        const batch = imagePaths.slice(i, i + batchSize);
        deletePromises.push(supabaseAdmin.storage.from('wish-images').remove(batch).catch((error)=>{
          console.error('Error removing batch of images:', error);
          return null; // Continuer même si une batch échoue
        }));
      }
    }
    // Supprimer l'avatar si présent
    if (!profileResult.error && profileResult.data?.avatar_url) {
      deletePromises.push(supabaseAdmin.storage.from('avatars').remove([
        profileResult.data.avatar_url
      ]).catch((error)=>{
        console.error('Error deleting avatar:', error);
        return null; // Continuer même si la suppression de l'avatar échoue
      }));
    }
    // 4. Exécuter toutes les suppressions de fichiers en parallèle
    await Promise.all(deletePromises);
    // 5. Supprimer l'utilisateur de auth.users
    // Cela déclenchera automatiquement la suppression en cascade
    // de toutes les données associées si les contraintes ON DELETE CASCADE sont bien configurées
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (deleteError) {
      throw deleteError;
    }
    // 6. Révoquer les jetons Sign in with Apple (guideline App Store 5.1.1(v)).
    // Après la suppression : un échec de celle-ci laisse le compte et son
    // autorisation Apple cohérents. Un échec de la révocation ne bloque rien,
    // l'utilisateur est parti, et chaque cas sauté laisse une trace.
    await revokeAppleAuthorization(appleAuthorizationCode, appleUserId);
    return new Response(JSON.stringify({
      message: 'Account deleted successfully'
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'Connection': 'keep-alive'
      },
      status: 200
    });
  } catch (error) {
    console.error('Error deleting account:', error);
    return new Response(JSON.stringify({
      error: (error as Error).message
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'Connection': 'keep-alive'
      },
      status: 500
    });
  }
});
