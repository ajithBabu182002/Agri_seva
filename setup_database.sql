-- 1. Create a table for public profiles with all the user information
alter table profiles add column if not exists avatar_url text;
alter table profiles add column if not exists email_id text;

-- (Run the rest if starting fresh, otherwise just the column add above)
-- create table profiles (
--   id uuid references auth.users not null primary key,
--   updated_at timestamp with time zone,
--   full_name text,
--   phone_number text,
--   email_id text,
--   address text,
--   country text,
--   state text,
--   pin_code text,
--   avatar_url text
-- );

-- 2. Set up Storage for Profile Pictures
-- Note: You need to create a bucket named 'avatars' in the Supabase Dashboard
-- Once created, run these policies:

-- Allow public access to view avatars
create policy "Avatar images are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'avatars' );

-- Allow users to upload their own avatar
create policy "Anyone can upload an avatar."
  on storage.objects for insert
  with check ( bucket_id = 'avatars' );

-- Allow users to update their own avatar
create policy "Anyone can update their own avatar."
  on storage.objects for update
  using ( auth.uid() = owner )
  with check ( bucket_id = 'avatars' );

-- Allow users to delete their own avatar
create policy "Anyone can delete their own avatar."
  on storage.objects for delete
  using ( auth.uid() = owner );
