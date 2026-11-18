-- Aplicar MANUALMENTE después de 202611180001. Bucket privado, máximo 3 MiB.
begin;
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('found-item-photos','found-item-photos',false,3145728,
  array['image/jpeg','image/png','image/webp']);

-- Se permite subir antes de insertar la fila. Ningún otro usuario puede leer
-- el archivo provisional: solo se comparte el photo_path vinculado a una fila visible.
create policy found_photos_insert_own on storage.objects for insert to authenticated
with check (
  bucket_id = 'found-item-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.](jpg|png|webp)$'
);
create policy found_photos_read_visible on storage.objects for select to authenticated
using (bucket_id = 'found-item-photos' and (
  (storage.foldername(name))[1] = (select auth.uid())::text
  or exists (select 1 from public.found_items f where f.photo_path = name and f.status = 'active')
));
create policy found_photos_delete_unlinked on storage.objects for delete to authenticated
using (bucket_id = 'found-item-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (select 1 from public.found_items f where f.photo_path = name)
);
-- Sin UPDATE: no hay sobrescritura (ni siquiera de fotos propias). Cada reemplazo
-- sube una ruta nueva, actualiza la publicación y después elimina la anterior.

-- Las políticas permisivas de Storage se combinan con OR. Estas restricciones
-- protegen este bucket aunque el proyecto tenga una política amplia anterior;
-- no cambian el acceso a los demás buckets.
create policy found_photos_guard_anon on storage.objects as restrictive
for all to anon using (bucket_id <> 'found-item-photos')
with check (bucket_id <> 'found-item-photos');
create policy found_photos_guard_read on storage.objects as restrictive
for select to authenticated using (bucket_id <> 'found-item-photos' or (
  (select auth.uid()) is not null and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists(select 1 from public.found_items f where f.photo_path=name and f.status='active')
  )
));
create policy found_photos_guard_insert on storage.objects as restrictive
for insert to authenticated with check (bucket_id <> 'found-item-photos' or (
  (select auth.uid()) is not null
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.](jpg|png|webp)$'
));
create policy found_photos_guard_update on storage.objects as restrictive
for update to authenticated using (bucket_id <> 'found-item-photos')
with check (bucket_id <> 'found-item-photos');
create policy found_photos_guard_delete on storage.objects as restrictive
for delete to authenticated using (bucket_id <> 'found-item-photos' or (
  (select auth.uid()) is not null
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists(select 1 from public.found_items f where f.photo_path=name)
));
commit;
