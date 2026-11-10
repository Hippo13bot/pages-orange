/* Google Contacts + Instagram export imports for Pages Orange.
   Google requires an OAuth Web client ID configured by the app owner.
   Instagram does not expose private personal address books through a public API. */
(() => {
  const $ = id => document.getElementById(id);
  let googleTokenClient = null;
  let googleAccessToken = null;

  function integrationStatus(id, message, ok = false) {
    const el = $(id);
    if (!el) return;
    el.textContent = message;
    el.className = 'small-note integration-status' + (ok ? ' ready' : '');
  }

  function googleClientId() {
    return localStorage.getItem('pages-orange-google-client-id') || '';
  }

  function initGoogleOAuth() {
    const field = $('googleClientId');
    if (field) field.value = googleClientId();
    if (!window.google?.accounts?.oauth2) {
      integrationStatus('googleStatus', 'Le module de connexion Google se charge à l’ouverture de la page.');
      return;
    }
    googleTokenClient = google.accounts.oauth2.initTokenClient({
      client_id: googleClientId(),
      scope: 'https://www.googleapis.com/auth/contacts.readonly',
      callback: async response => {
        if (response.error) {
          integrationStatus('googleStatus', 'Connexion Google refusée : ' + response.error);
          return;
        }
        googleAccessToken = response.access_token;
        await importGoogleContacts();
      }
    });
    integrationStatus('googleStatus', googleClientId()
      ? 'Prêt à connecter Google Contacts.'
      : 'Ajoutez votre identifiant OAuth Google pour activer la connexion.');
  }

  $('googleSaveClient')?.addEventListener('click', () => {
    const value = $('googleClientId').value.trim();
    if (!value.endsWith('.apps.googleusercontent.com')) {
      integrationStatus('googleStatus', 'Identifiant OAuth invalide : il doit se terminer par .apps.googleusercontent.com.');
      return;
    }
    localStorage.setItem('pages-orange-google-client-id', value);
    initGoogleOAuth();
    integrationStatus('googleStatus', 'Identifiant enregistré sur cet appareil. Vous pouvez connecter Google.');
  });

  $('googleConnect')?.addEventListener('click', () => {
    if (!googleClientId()) {
      integrationStatus('googleStatus', 'Enregistrez d’abord votre identifiant OAuth Google.');
      return;
    }
    if (!window.google?.accounts?.oauth2) {
      integrationStatus('googleStatus', 'Le service Google ne s’est pas chargé. Rechargez la page.');
      return;
    }
    if (!googleTokenClient) initGoogleOAuth();
    googleTokenClient.requestAccessToken({ prompt: 'consent' });
  });

  $('googleDisconnect')?.addEventListener('click', () => {
    if (googleAccessToken && window.google?.accounts?.oauth2) {
      google.accounts.oauth2.revoke(googleAccessToken, () => {});
    }
    googleAccessToken = null;
    integrationStatus('googleStatus', 'Déconnecté de Google.');
  });

  async function importGoogleContacts() {
    try {
      let pageToken = '';
      const rows = [];
      do {
        const url = new URL('https://people.googleapis.com/v1/people/me/connections');
        url.searchParams.set('personFields', 'names,emailAddresses,phoneNumbers,organizations');
        url.searchParams.set('pageSize', '1000');
        if (pageToken) url.searchParams.set('pageToken', pageToken);
        const response = await fetch(url, { headers: { Authorization: 'Bearer ' + googleAccessToken } });
        if (!response.ok) throw new Error('Google Contacts : ' + response.status + ' ' + response.statusText);
        const data = await response.json();
        for (const p of data.connections || []) {
          const n = p.names?.[0] || {};
          const org = p.organizations?.[0] || {};
          rows.push({
            'first name': n.givenName || '',
            'last name': n.familyName || '',
            email: p.emailAddresses?.[0]?.value || '',
            phone: p.phoneNumbers?.[0]?.value || '',
            company: org.name || '',
            title: org.title || ''
          });
        }
        pageToken = data.nextPageToken || '';
      } while (pageToken);
      await importRows(rows, 'Google Contacts');
      integrationStatus('googleStatus', rows.length + ' contact(s) Google traités. Les doublons ont été ignorés.', true);
    } catch (error) {
      integrationStatus('googleStatus', error.message || 'Erreur pendant l’import Google.');
    }
  }

  function flattenInstagramExport(data) {
    const out = [];
    const seen = new Set();
    const add = (username, href = '') => {
      const handle = String(username || '').replace(/^@/, '').trim();
      if (!handle || seen.has(handle.toLowerCase())) return;
      seen.add(handle.toLowerCase());
      out.push({ instagram: handle, website: href || (handle ? 'https://www.instagram.com/' + encodeURIComponent(handle) + '/' : ''), notes: 'Importé depuis un export Instagram' });
    };
    const walk = value => {
      if (!value) return;
      if (Array.isArray(value)) { value.forEach(walk); return; }
      if (typeof value !== 'object') return;
      const title = value.title || value.string_list_data?.[0]?.value || '';
      const href = value.href || value.string_list_data?.[0]?.href || '';
      if (title || href) {
        const fromUrl = href.match(/instagram\.com\/([^/?#]+)/i)?.[1];
        add(title || fromUrl, href);
      }
      for (const [key, child] of Object.entries(value)) {
        if (['relationships_following','relationships_followers','followers','following','close_friends','pending_follow_requests'].includes(key)) walk(child);
      }
    };
    walk(data);
    return out;
  }

  $('instagramExportFile')?.addEventListener('change', async event => {
    const file = event.target.files?.[0];
    if (!file) return;
    try {
      const raw = await file.text();
      let rows;
      if (/\.json$/i.test(file.name)) {
        rows = flattenInstagramExport(JSON.parse(raw));
      } else {
        rows = parseCSV(raw).map(r => {
          const values = Object.values(r);
          const url = values.find(v => /instagram\.com\//i.test(v)) || '';
          const username = url.match(/instagram\.com\/([^/?#]+)/i)?.[1] || values.find(v => /^@?[a-z0-9._]{2,30}$/i.test(v)) || '';
          return { instagram: username, website: url };
        }).filter(r => r.instagram);
      }
      if (!rows.length) throw new Error('Aucun profil Instagram reconnu dans ce fichier. Essayez l’export JSON « Abonnés et abonnements ».');
      await importRows(rows, 'Export Instagram — ' + file.name);
      integrationStatus('instagramStatus', rows.length + ' profil(s) détecté(s). Les doublons ont été ignorés.', true);
    } catch (error) {
      integrationStatus('instagramStatus', error.message || 'Impossible de lire cet export Instagram.');
    }
    event.target.value = '';
  });

  window.addEventListener('load', initGoogleOAuth);
  window.addEventListener('google-gsi-ready', initGoogleOAuth);
})();
