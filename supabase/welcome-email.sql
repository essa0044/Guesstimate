-- Guesstimate welcome email: one short email to every new account, sent through Resend.
--
-- Setup (once):
--   1. Run this whole file: SQL Editor > New query > paste everything > Run.
--   2. In Resend, go to API Keys > Create API key. Name it "Supabase welcome email",
--      permission "Sending access", domain "playguesstimate.com". Copy the key (it starts with re_).
--   3. In a new SQL query, run this line with your key pasted in place of re_xxx:
--        select vault.create_secret('re_xxx', 'resend_api_key');
--      The key is stored encrypted in Supabase Vault. It never appears on the website.
--
-- Until step 3 is done, sign-ups work exactly as before and simply get no email.
-- If sending ever fails, the sign-up still goes through: the email is sent in the background.
--
-- This is a service email (it only confirms the account and explains how to play), so it's
-- allowed without the news checkbox. Keep promotions out of it.
--
-- To change the key later:
--   select vault.update_secret((select id from vault.secrets where name = 'resend_api_key'), 're_new');
-- To stop welcome emails:
--   drop trigger if exists on_auth_user_welcome on auth.users;

create extension if not exists pg_net with schema extensions;

create or replace function public.send_welcome_email()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_key  text;
  v_name text;
  v_safe text;
  v_line text;
  v_html text;
  v_text text;
begin
  if new.email is null then
    return new;
  end if;
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'resend_api_key' limit 1;
  if v_key is null or v_key = '' then
    return new;
  end if;

  -- The profile is created by on_auth_user_created, which runs first.
  select username into v_name from public.profiles where id = new.id;
  v_safe := replace(replace(replace(replace(coalesce(v_name, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
  v_line := case when v_name is null
    then 'Open the game to choose the name other players will see on the leaderboard.'
    else 'Your name on the leaderboard is <b>' || v_safe || '</b>.' end;

  v_html := '<!doctype html><html><body style="margin:0;padding:0;background:#ECF0F4;">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#ECF0F4;padding:32px 16px;">'
    || '<tr><td align="center">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:12px;font-family:Helvetica,Arial,sans-serif;color:#152238;">'
    || '<tr><td style="padding:32px 28px 8px;font-size:28px;font-weight:800;letter-spacing:-0.5px;color:#B91F4A;">guesstimate</td></tr>'
    || '<tr><td style="padding:8px 28px 0;font-size:22px;font-weight:700;line-height:1.3;">Welcome' || case when v_name is null then '' else ', ' || v_safe end || '!</td></tr>'
    || '<tr><td style="padding:12px 28px 0;font-size:16px;line-height:1.55;color:#3B4963;">'
    || 'Your Guesstimate account is ready. ' || v_line
    || '</td></tr>'
    || '<tr><td style="padding:12px 28px 0;font-size:16px;line-height:1.55;color:#3B4963;">'
    || 'Every day there''s a new set of five quick estimation games, the same for everyone. '
    || 'Your first try of the day goes on the leaderboard, and your streak follows you to any device you sign in on.'
    || '</td></tr>'
    || '<tr><td style="padding:24px 28px 8px;">'
    || '<a href="https://playguesstimate.com/" style="display:inline-block;background:#B91F4A;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px;padding:14px 26px;border-radius:999px;">Play today''s five</a>'
    || '</td></tr>'
    || '<tr><td style="padding:16px 28px 28px;font-size:13px;line-height:1.5;color:#56647A;">'
    || 'You can change your name or delete your account any time from the account screen in the game. '
    || 'You got this email because this address was used to create a Guesstimate account. If that wasn''t you, reply and we''ll delete it.'
    || '</td></tr>'
    || '</table>'
    || '<p style="font-family:Helvetica,Arial,sans-serif;font-size:12px;color:#56647A;margin:16px 0 0;">'
    || '<a href="https://playguesstimate.com/" style="color:#56647A;">playguesstimate.com</a> · '
    || '<a href="https://playguesstimate.com/impressum" style="color:#56647A;">Impressum</a> · '
    || '<a href="https://playguesstimate.com/privacy" style="color:#56647A;">Privacy</a></p>'
    || '</td></tr></table></body></html>';

  v_text := 'Welcome' || case when v_name is null then '' else ', ' || v_name end || '!' || chr(10) || chr(10)
    || 'Your Guesstimate account is ready. '
    || case when v_name is null then 'Open the game to choose the name other players will see on the leaderboard.'
            else 'Your name on the leaderboard is ' || v_name || '.' end || chr(10) || chr(10)
    || 'Every day there''s a new set of five quick estimation games, the same for everyone. '
    || 'Your first try of the day goes on the leaderboard, and your streak follows you to any device you sign in on.' || chr(10) || chr(10)
    || 'Play today''s five: https://playguesstimate.com/' || chr(10) || chr(10)
    || 'You can change your name or delete your account any time from the account screen in the game. '
    || 'You got this email because this address was used to create a Guesstimate account. If that wasn''t you, reply and we''ll delete it.' || chr(10) || chr(10)
    || 'Impressum: https://playguesstimate.com/impressum';

  perform net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json'),
    body    := jsonb_build_object(
                 'from', 'Guesstimate <hello@playguesstimate.com>',
                 'to', jsonb_build_array(new.email),
                 'reply_to', 'hello@playguesstimate.com',
                 'subject', 'Welcome to Guesstimate',
                 'html', v_html,
                 'text', v_text)
  );
  return new;
exception when others then
  -- Never block a sign-up because of the email.
  return new;
end;
$$;

revoke all on function public.send_welcome_email() from public, anon, authenticated;

-- Triggers run in name order, so on_auth_user_created (which makes the profile) runs first.
drop trigger if exists on_auth_user_welcome on auth.users;
create trigger on_auth_user_welcome
  after insert on auth.users
  for each row execute function public.send_welcome_email();
