# Backend connectors — configuration guide

Notion OAuth and Supabase sync are intentionally not exposed as fake buttons in the client.

## Required server-side environment variables
- `NOTION_CLIENT_ID`
- `NOTION_CLIENT_SECRET`
- `NOTION_REDIRECT_URI`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (server only; never expose to browser)

## Notion bidirectional sync
Implement OAuth authorization-code flow server-side, store access tokens encrypted per workspace, then:
1. Let the user choose a Notion database and map properties.
2. Store `notion_page_id`, `notion_last_edited_time`, `local_updated_at`, and sync cursor.
3. Pull changed pages using Notion API; push local changes using server API.
4. Resolve simultaneous edits with a conflict queue. Never silently overwrite.
5. Log sync outcomes and allow disconnect/revoke.

This folder is a guide, not a live integration. OAuth credentials and user authorization are required.
