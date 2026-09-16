use std::{
    collections::hash_map::DefaultHasher,
    collections::HashSet,
    hash::{Hash, Hasher},
    io::Cursor,
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
    time::{SystemTime, UNIX_EPOCH},
};

use chrono::{DateTime, Local};
use image::{imageops, DynamicImage, GenericImageView};
use serde::{Deserialize, Serialize};
use walkdir::WalkDir;

const IMAGE_EXTENSIONS: &[&str] = &[
    "jpg", "jpeg", "png", "gif", "bmp", "webp", "tiff", "tif", "heic", "heif", "avif",
];

const STATE_FILE: &str = "nexora_core.json";

#[derive(Debug, Clone, Serialize)]
pub struct Photo {
    pub path: String,
    pub name: String,
    pub extension: String,
    pub size_bytes: u64,
    pub width: u32,
    pub height: u32,
    pub taken_at: Option<String>,
    pub is_favorite: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Album {
    pub id: String,
    pub name: String,
    pub photo_paths: Vec<String>,
    pub created_at: String,
}

use crate::store::StoreData;

#[flutter_rust_bridge::frb(opaque)]
pub struct PhotoStore {
    data: Arc<Mutex<StoreData>>,
    config_dir: String,
}

fn read_photo(path: &Path, is_favorite: bool) -> Photo {
    let meta = std::fs::metadata(path);
    let (size_bytes, modified) = match meta {
        Ok(m) => (m.len(), m.modified().ok()),
        Err(_) => (0, None),
    };

    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();
    let extension = path
        .extension()
        .map(|e| e.to_string_lossy().to_lowercase())
        .unwrap_or_default();

    let (width, height) = imagesize::size(path)
        .map(|s| (s.width as u32, s.height as u32))
        .unwrap_or((0, 0));

    let taken_at = exif_taken_at(path).or_else(|| modified.map(format_local));

    Photo {
        path: path.to_string_lossy().to_string(),
        name,
        extension,
        size_bytes,
        width,
        height,
        taken_at,
        is_favorite,
    }
}

fn exif_taken_at(path: &Path) -> Option<String> {
    let file = std::fs::File::open(path).ok()?;
    let mut bufreader = std::io::BufReader::new(&file);
    let exif = exif::Reader::new()
        .read_from_container(&mut bufreader)
        .ok()?;
    for tag in &[
        exif::Tag::DateTimeOriginal,
        exif::Tag::DateTimeDigitized,
        exif::Tag::DateTime,
    ] {
        if let Some(field) = exif.get_field(*tag, exif::In::PRIMARY) {
            let display = field.display_value().to_string();
            if let Ok(dt) = DateTime::parse_from_str(&display, "%Y-%m-%d %H:%M:%S") {
                return Some(dt.with_timezone(&Local).to_rfc3339());
            }
        }
    }
    None
}

fn format_local(t: SystemTime) -> String {
    let dt: DateTime<Local> = t.into();
    dt.to_rfc3339()
}

fn unix_ms() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis().to_string())
        .unwrap_or_default()
}

const THUMBS_DIR: &str = "thumbs";

fn cache_key_for(path: &str, modified_secs: u64, size: u64) -> String {
    let mut hasher = DefaultHasher::new();
    path.hash(&mut hasher);
    modified_secs.hash(&mut hasher);
    size.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

fn clear_thumbnail_file(config_dir: &str, path: &str) {
    let modified = std::fs::metadata(path)
        .ok()
        .and_then(|m| m.modified().ok())
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let size = std::fs::metadata(path).map(|m| m.len()).unwrap_or(0);
    let key = cache_key_for(path, modified, size);
    let _ = std::fs::remove_file(
        Path::new(config_dir)
            .join(THUMBS_DIR)
            .join(format!("{key}.jpg")),
    );
}

impl PhotoStore {
    pub fn new(config_dir: String) -> Result<PhotoStore, String> {
        let dir = PathBuf::from(&config_dir);
        std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;

        let data = Self::load(&dir.join(STATE_FILE)).unwrap_or_default();
        Ok(PhotoStore {
            data: Arc::new(Mutex::new(data)),
            config_dir,
        })
    }

    fn load(path: &Path) -> Option<StoreData> {
        let raw = std::fs::read_to_string(path).ok()?;
        serde_json::from_str(&raw).ok()
    }

    fn save(&self) -> Result<(), String> {
        let lock = self.data.lock().map_err(|e| e.to_string())?;
        let raw = serde_json::to_string_pretty(&*lock).map_err(|e| e.to_string())?;
        std::fs::write(self.config_dir.clone() + "/" + STATE_FILE, raw).map_err(|e| e.to_string())
    }

    pub fn scan_directory(&self, root: String) -> Result<Vec<Photo>, String> {
        let base = PathBuf::from(&root);
        if !base.is_dir() {
            return Err(format!("Not a directory: {root}"));
        }

        let favorites: HashSet<String> = self
            .data
            .lock()
            .map_err(|e| e.to_string())?
            .favorite_paths
            .iter()
            .cloned()
            .collect();

        let mut photos = Vec::new();
        for entry in WalkDir::new(&base).into_iter().filter_map(|e| e.ok()) {
            if !entry.file_type().is_file() {
                continue;
            }
            let path = entry.path();
            let ext = path
                .extension()
                .map(|e| e.to_string_lossy().to_lowercase())
                .unwrap_or_default();
            if !IMAGE_EXTENSIONS.contains(&ext.as_str()) {
                continue;
            }
            let absolutized = path.to_path_buf();
            let photo = read_photo(
                &absolutized,
                favorites.contains(&absolutized.to_string_lossy().to_string()),
            );
            photos.push(photo);
        }
        photos.sort_by(|a, b| b.taken_at.cmp(&a.taken_at));
        Ok(photos)
    }

    pub fn get_photos(&self, paths: Vec<String>) -> Result<Vec<Photo>, String> {
        let favorites: HashSet<String> = self
            .data
            .lock()
            .map_err(|e| e.to_string())?
            .favorite_paths
            .iter()
            .cloned()
            .collect();

        Ok(paths
            .into_iter()
            .map(|p| read_photo(Path::new(&p), favorites.contains(&p)))
            .collect())
    }

    pub fn set_favorite(&self, path: String, is_favorite: bool) -> Result<(), String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        let favs = &mut lock.favorite_paths;
        if is_favorite {
            if !favs.contains(&path) {
                favs.push(path);
            }
        } else {
            favs.retain(|p| p != &path);
        }
        drop(lock);
        self.save()
    }

    pub fn favorite_paths(&self) -> Result<Vec<String>, String> {
        Ok(self
            .data
            .lock()
            .map_err(|e| e.to_string())?
            .favorite_paths
            .clone())
    }

    pub fn list_albums(&self) -> Result<Vec<Album>, String> {
        Ok(self.data.lock().map_err(|e| e.to_string())?.albums.clone())
    }

    pub fn create_album(&self, name: String) -> Result<Album, String> {
        let album = Album {
            id: unix_ms(),
            name,
            photo_paths: Vec::new(),
            created_at: format_local(SystemTime::now()),
        };
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        lock.albums.push(album.clone());
        drop(lock);
        self.save()?;
        Ok(album)
    }

    pub fn add_photos_to_album(
        &self,
        album_id: String,
        photos: Vec<String>,
    ) -> Result<Album, String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        let album = lock
            .albums
            .iter_mut()
            .find(|a| a.id == album_id)
            .ok_or_else(|| format!("Album not found: {album_id}"))?;
        for p in photos {
            if !album.photo_paths.contains(&p) {
                album.photo_paths.push(p);
            }
        }
        let result = album.clone();
        drop(lock);
        self.save()?;
        Ok(result)
    }

    pub fn remove_photos_from_album(
        &self,
        album_id: String,
        photos: Vec<String>,
    ) -> Result<Album, String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        let album = lock
            .albums
            .iter_mut()
            .find(|a| a.id == album_id)
            .ok_or_else(|| format!("Album not found: {album_id}"))?;
        album.photo_paths.retain(|p| !photos.contains(p));
        let result = album.clone();
        drop(lock);
        self.save()?;
        Ok(result)
    }

    pub fn rename_album(&self, album_id: String, new_name: String) -> Result<Album, String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        let album = lock
            .albums
            .iter_mut()
            .find(|a| a.id == album_id)
            .ok_or_else(|| format!("Album not found: {album_id}"))?;
        album.name = new_name;
        let result = album.clone();
        drop(lock);
        self.save()?;
        Ok(result)
    }

    pub fn delete_album(&self, album_id: String) -> Result<(), String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        lock.albums.retain(|a| a.id != album_id);
        drop(lock);
        self.save()
    }

    pub fn thumbnail_bytes(&self, path: String, size: u32) -> Result<Option<Vec<u8>>, String> {
        let img_path = Path::new(&path);
        if !img_path.is_file() {
            clear_thumbnail_file(&self.config_dir, &path);
            return Ok(None);
        }

        let meta = std::fs::metadata(img_path).map_err(|e| e.to_string())?;
        let modified = meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        let key = cache_key_for(&path, modified, meta.len());

        let thumbs_dir = Path::new(&self.config_dir).join(THUMBS_DIR);
        std::fs::create_dir_all(&thumbs_dir).map_err(|e| e.to_string())?;
        let cache_file = thumbs_dir.join(format!("{key}.jpg"));
        if cache_file.is_file() {
            return Ok(Some(std::fs::read(&cache_file).map_err(|e| e.to_string())?));
        }

        let img = match image::open(img_path) {
            Ok(img) => img,
            Err(_) => return Ok(None),
        };
        let (w, h) = img.dimensions();
        let max = w.max(h).max(1);
        let target = size.max(1);
        let (nw, nh) = if max <= target {
            (w, h)
        } else {
            let scale = target as f32 / max as f32;
            (
                ((w as f32 * scale).round().max(1.0)) as u32,
                ((h as f32 * scale).round().max(1.0)) as u32,
            )
        };
        let thumb = imageops::thumbnail(&img, nw, nh);
        let mut buf = Cursor::new(Vec::new());
        DynamicImage::ImageRgba8(thumb)
            .write_to(&mut buf, image::ImageFormat::Jpeg)
            .map_err(|e| e.to_string())?;
        let bytes = buf.into_inner();
        let _ = std::fs::write(&cache_file, &bytes);
        Ok(Some(bytes))
    }

    pub fn delete_photo(&self, path: String) -> Result<(), String> {
        clear_thumbnail_file(&self.config_dir, &path);
        std::fs::remove_file(&path).map_err(|e| e.to_string())?;

        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        lock.favorite_paths.retain(|p| p != &path);
        for album in &mut lock.albums {
            album.photo_paths.retain(|p| p != &path);
        }
        drop(lock);
        self.save()
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp_dir(tag: &str) -> String {
        let dir = std::env::temp_dir().join(format!("nexora_test_{tag}_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        dir.to_string_lossy().to_string()
    }

    // 1x1 red PNG
    const TINY_PNG: &[u8] = &[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44,
        0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90,
        0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8,
        0xCF, 0xC0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x01, 0x2C, 0x9B, 0x93, 0x00, 0x00, 0x00, 0x00,
        0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];

    #[test]
    fn scan_find_and_metadata() {
        let root = tmp_dir("scan");
        let config = tmp_dir("scan_cfg");
        std::fs::write(std::path::Path::new(&root).join("a.PNG"), TINY_PNG).unwrap();
        std::fs::write(
            std::path::Path::new(&root).join("note.txt"),
            b"not an image",
        )
        .unwrap();

        let store = PhotoStore::new(config).unwrap();
        let photos = store.scan_directory(root).unwrap();
        assert_eq!(photos.len(), 1);
        assert_eq!(photos[0].name, "a.PNG");
        assert_eq!(photos[0].width, 1);
        assert_eq!(photos[0].height, 1);
    }

    #[test]
    fn favorites_persist() {
        let config = tmp_dir("fav_cfg");
        let store = PhotoStore::new(config.clone()).unwrap();
        store.set_favorite("/foto.jpg".into(), true).unwrap();
        assert_eq!(store.favorite_paths().unwrap(), vec!["/foto.jpg"]);
        store.set_favorite("/foto.jpg".into(), false).unwrap();
        assert!(store.favorite_paths().unwrap().is_empty());

        let reloaded = PhotoStore::new(config.clone()).unwrap();
        assert!(reloaded.favorite_paths().unwrap().is_empty());
        store.set_favorite("/persistido.png".into(), true).unwrap();
        let reloaded_again = PhotoStore::new(config).unwrap();
        assert_eq!(
            reloaded_again.favorite_paths().unwrap(),
            vec!["/persistido.png"]
        );
    }

    #[test]
    fn albums_crud() {
        let config = tmp_dir("alb_cfg");
        let store = PhotoStore::new(config).unwrap();
        let album = store.create_album("Vacaciones".into()).unwrap();
        let updated = store
            .add_photos_to_album(album.id.clone(), vec!["a.jpg".into(), "b.jpg".into()])
            .unwrap();
        assert_eq!(updated.photo_paths.len(), 2);
        let renamed = store
            .rename_album(album.id.clone(), "Viaje".into())
            .unwrap();
        assert_eq!(renamed.name, "Viaje");
        let removed = store
            .remove_photos_from_album(album.id.clone(), vec!["a.jpg".into()])
            .unwrap();
        assert_eq!(removed.photo_paths, vec!["b.jpg"]);
        store.delete_album(album.id.clone()).unwrap();
        assert!(store.list_albums().unwrap().is_empty());
    }

    #[test]
    fn thumbnail_generates_and_caches() {
        let root = tmp_dir("thumb");
        let config = tmp_dir("thumb_cfg");
        let png_path = std::path::Path::new(&root).join("foto.png");
        let img = image::RgbImage::from_pixel(60, 40, image::Rgb([200, 30, 30]));
        img.save(&png_path).unwrap();
        let store = PhotoStore::new(config.clone()).unwrap();

        let bytes = store
            .thumbnail_bytes(png_path.to_string_lossy().to_string(), 256)
            .unwrap();
        assert!(bytes.is_some());
        assert!(!bytes.unwrap().is_empty());
        // En caché: la segunda llamada también devuelve bytes
        let again = store
            .thumbnail_bytes(png_path.to_string_lossy().to_string(), 256)
            .unwrap();
        assert!(again.is_some());
        assert!(!again.unwrap().is_empty());
        // Caché persistida en disco bajo thumbs/
        let thumbs = std::path::Path::new(&config).join("thumbs");
        assert!(std::fs::read_dir(&thumbs).unwrap().count() > 0);
        // Deno existe -> None
        let missing = store.thumbnail_bytes("/no/existe.jpg".into(), 256).unwrap();
        assert!(missing.is_none());
    }

    #[test]
    fn delete_photo_removes_file_and_state() {
        let root = tmp_dir("del");
        let config = tmp_dir("del_cfg");
        let png_path = std::path::Path::new(&root).join("foto.png");
        std::fs::write(&png_path, TINY_PNG).unwrap();
        let store = PhotoStore::new(config).unwrap();

        let p = png_path.to_string_lossy().to_string();
        store.set_favorite(p.clone(), true).unwrap();
        let album = store.create_album("A".into()).unwrap();
        store
            .add_photos_to_album(album.id, vec![p.clone()])
            .unwrap();

        store.delete_photo(p.clone()).unwrap();

        assert!(!png_path.exists());
        assert!(store.favorite_paths().unwrap().is_empty());
        let albums = store.list_albums().unwrap();
        assert!(albums[0].photo_paths.is_empty());
    }
}
