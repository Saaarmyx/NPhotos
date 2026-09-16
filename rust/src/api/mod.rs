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

const VIDEO_EXTENSIONS: &[&str] = &["mp4", "mov", "mkv", "webm", "avi", "m4v", "3gp"];

/// Carpetas de ruido que se saltan al escanear todo el sistema.
const NOISE_DIRS: &[&str] = &[
    "node_modules",
    "target",
    "build",
    "dist",
    "Pods",
    "__pycache__",
    "venv",
    "env",
    "lost+found",
    "snap",
];

fn home_dir() -> Result<PathBuf, String> {
    std::env::var("HOME")
        .map(PathBuf::from)
        .map_err(|_| "HOME not set".to_string())
}

/// Omitir entradas ocultas, la carpeta de config de la app y ruido conocido.
fn is_noise_dir(path: &Path, config_dir: &Path) -> bool {
    if path.starts_with(config_dir) || path.as_os_str().is_empty() {
        return true;
    }
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    name.starts_with('.') || NOISE_DIRS.contains(&name.as_str())
}

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

#[derive(Debug, Clone, Serialize)]
pub struct VideoFile {
    pub path: String,
    pub name: String,
    pub extension: String,
    pub size_bytes: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct MovedEntry {
    pub name: String,
    pub path: String,
    pub original: String,
    pub size_bytes: u64,
}

use crate::store::{MovedItem, StoreData};

#[flutter_rust_bridge::frb(opaque)]
pub struct PhotoStore {
    data: Arc<Mutex<StoreData>>,
    config_dir: String,
}

/// Orden cronológico: recientes primero, desempate estable por nombre.
fn sort_chrono(photos: &mut [Photo]) {
    photos.sort_by(|a, b| {
        b.taken_at
            .cmp(&a.taken_at)
            .then_with(|| b.name.cmp(&a.name))
    });
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
const TRASH_DIR: &str = "trash";
const SECURE_DIR: &str = "secure";

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
        self.collect_photos(&base, false)
    }

    /// Escanea todas las fotos del equipo (desde $HOME), saltando carpetas
    /// ocultas y de ruido, y excluyendo la configuración/papelera/segura.
    pub fn scan_system(&self) -> Result<Vec<Photo>, String> {
        let home = home_dir()?;
        self.collect_photos(&home, true)
    }

    pub fn scan_system_videos(&self) -> Result<Vec<VideoFile>, String> {
        let home = home_dir()?;
        self.collect_videos(&home, true)
    }

    fn collect_photos(&self, root: &Path, skip_noise: bool) -> Result<Vec<Photo>, String> {
        let favorites: HashSet<String> = self
            .data
            .lock()
            .map_err(|e| e.to_string())?
            .favorite_paths
            .iter()
            .cloned()
            .collect();

        let entries: Box<dyn Iterator<Item = walkdir::Result<walkdir::DirEntry>>> = if skip_noise {
            Box::new(WalkDir::new(root).into_iter().filter_entry(|e| {
                e.depth() == 0 || !is_noise_dir(e.path(), Path::new(&self.config_dir))
            }))
        } else {
            Box::new(WalkDir::new(root).into_iter())
        };
        let mut photos = Vec::new();
        for entry in entries.filter_map(|e| e.ok()) {
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
        sort_chrono(&mut photos);
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

        let mut photos: Vec<Photo> = paths
            .into_iter()
            .map(|p| read_photo(Path::new(&p), favorites.contains(&p)))
            .collect();
        sort_chrono(&mut photos);
        Ok(photos)
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

    pub fn move_to_trash(&self, path: String) -> Result<MovedEntry, String> {
        let items = self
            .data
            .lock()
            .map_err(|e| e.to_string())?
            .trash_items
            .clone();
        let src = Path::new(&path);
        if !src.is_file() {
            return Err(format!("Not a file: {path}"));
        }
        let name = unique_name(src, &items);
        let moved = move_file(&self.config_dir, TRASH_DIR, src, &name)?;

        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        lock.favorite_paths.retain(|p| p != &path);
        for album in &mut lock.albums {
            album.photo_paths.retain(|p| p != &path);
        }
        lock.trash_items.push(MovedItem {
            name: name.clone(),
            original: path,
        });
        drop(lock);
        self.save()?;
        Ok(moved)
    }

    pub fn list_trash(&self) -> Result<Vec<MovedEntry>, String> {
        let lock = self.data.lock().map_err(|e| e.to_string())?;
        let trash_dir = Path::new(&self.config_dir).join(TRASH_DIR);
        Ok(lock
            .trash_items
            .iter()
            .map(|item| MovedEntry {
                name: item.name.clone(),
                path: trash_dir.join(&item.name).to_string_lossy().to_string(),
                original: item.original.clone(),
                size_bytes: file_size(&trash_dir.join(&item.name)),
            })
            .collect())
    }

    pub fn restore_trash(&self, name: String) -> Result<(), String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        let item = lock
            .trash_items
            .iter()
            .find(|i| i.name == name)
            .cloned()
            .ok_or_else(|| format!("Not in trash: {name}"))?;

        let src = Path::new(&self.config_dir).join(TRASH_DIR).join(&name);
        let dest = Path::new(&item.original);
        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        std::fs::rename(src, dest).map_err(|e| e.to_string())?;
        lock.trash_items.retain(|i| i.name != name);
        drop(lock);
        self.save()
    }

    pub fn delete_trash_item(&self, name: String) -> Result<(), String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        std::fs::remove_file(Path::new(&self.config_dir).join(TRASH_DIR).join(&name))
            .map_err(|e| e.to_string())?;
        lock.trash_items.retain(|i| i.name != name);
        drop(lock);
        self.save()
    }

    pub fn empty_trash(&self) -> Result<(), String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        for item in &lock.trash_items {
            let _ =
                std::fs::remove_file(Path::new(&self.config_dir).join(TRASH_DIR).join(&item.name));
        }
        lock.trash_items.clear();
        drop(lock);
        self.save()
    }

    pub fn scan_videos(&self, root: String) -> Result<Vec<VideoFile>, String> {
        let base = PathBuf::from(&root);
        if !base.is_dir() {
            return Err(format!("Not a directory: {root}"));
        }
        self.collect_videos(&base, false)
    }

    fn collect_videos(&self, root: &Path, skip_noise: bool) -> Result<Vec<VideoFile>, String> {
        let entries: Box<dyn Iterator<Item = walkdir::Result<walkdir::DirEntry>>> = if skip_noise {
            Box::new(WalkDir::new(root).into_iter().filter_entry(|e| {
                e.depth() == 0 || !is_noise_dir(e.path(), Path::new(&self.config_dir))
            }))
        } else {
            Box::new(WalkDir::new(root).into_iter())
        };
        let mut videos = Vec::new();
        for entry in entries.filter_map(|e| e.ok()) {
            if !entry.file_type().is_file() {
                continue;
            }
            let path = entry.path();
            let ext = path
                .extension()
                .map(|e| e.to_string_lossy().to_lowercase())
                .unwrap_or_default();
            if !VIDEO_EXTENSIONS.contains(&ext.as_str()) {
                continue;
            }
            let name = path
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_default();
            let size_bytes = std::fs::metadata(path).map(|m| m.len()).unwrap_or(0);
            videos.push(VideoFile {
                path: path.to_string_lossy().to_string(),
                name,
                extension: ext,
                size_bytes,
            });
        }
        videos.sort_by_key(|a| std::cmp::Reverse(a.name.to_lowercase()));
        Ok(videos)
    }

    pub fn move_to_secure(&self, path: String) -> Result<MovedEntry, String> {
        let items = self
            .data
            .lock()
            .map_err(|e| e.to_string())?
            .secure_items
            .clone();
        let src = Path::new(&path);
        if !src.is_file() {
            return Err(format!("Not a file: {path}"));
        }
        let name = unique_name(src, &items);
        let moved = move_file(&self.config_dir, SECURE_DIR, src, &name)?;

        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        lock.favorite_paths.retain(|p| p != &path);
        for album in &mut lock.albums {
            album.photo_paths.retain(|p| p != &path);
        }
        lock.secure_items.push(MovedItem {
            name: name.clone(),
            original: path,
        });
        drop(lock);
        self.save()?;
        Ok(moved)
    }

    pub fn list_secure(&self) -> Result<Vec<MovedEntry>, String> {
        let lock = self.data.lock().map_err(|e| e.to_string())?;
        let secure_dir = Path::new(&self.config_dir).join(SECURE_DIR);
        Ok(lock
            .secure_items
            .iter()
            .map(|item| MovedEntry {
                name: item.name.clone(),
                path: secure_dir.join(&item.name).to_string_lossy().to_string(),
                original: item.original.clone(),
                size_bytes: file_size(&secure_dir.join(&item.name)),
            })
            .collect())
    }

    pub fn restore_secure(&self, name: String) -> Result<(), String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        let item = lock
            .secure_items
            .iter()
            .find(|i| i.name == name)
            .cloned()
            .ok_or_else(|| format!("Not in secure folder: {name}"))?;
        let src = Path::new(&self.config_dir).join(SECURE_DIR).join(&name);
        let dest = Path::new(&item.original);
        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        std::fs::rename(src, dest).map_err(|e| e.to_string())?;
        lock.secure_items.retain(|i| i.name != name);
        drop(lock);
        self.save()
    }

    pub fn delete_secure_item(&self, name: String) -> Result<(), String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        std::fs::remove_file(Path::new(&self.config_dir).join(SECURE_DIR).join(&name))
            .map_err(|e| e.to_string())?;
        lock.secure_items.retain(|i| i.name != name);
        drop(lock);
        self.save()
    }

    pub fn set_pin(&self, pin: String) -> Result<(), String> {
        if pin.is_empty() {
            return Err("PIN vacío".to_string());
        }
        let hash = sha256(&pin);
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        lock.secure_pin_hash = Some(hash);
        drop(lock);
        self.save()
    }

    pub fn clear_pin(&self) -> Result<(), String> {
        let mut lock = self.data.lock().map_err(|e| e.to_string())?;
        lock.secure_pin_hash = None;
        drop(lock);
        self.save()
    }

    pub fn pin_is_set(&self) -> Result<bool, String> {
        Ok(self
            .data
            .lock()
            .map_err(|e| e.to_string())?
            .secure_pin_hash
            .is_some())
    }

    pub fn verify_pin(&self, pin: String) -> Result<bool, String> {
        let lock = self.data.lock().map_err(|e| e.to_string())?;
        Ok(lock
            .secure_pin_hash
            .as_ref()
            .map(|h| h == &sha256(&pin))
            .unwrap_or(false))
    }
}

fn file_size(path: &Path) -> u64 {
    std::fs::metadata(path).map(|m| m.len()).unwrap_or(0)
}

fn unique_name(src: &Path, existing: &[MovedItem]) -> String {
    let base = src
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();
    let name = base.clone();
    if existing.iter().all(|i| i.name != name) {
        return name;
    }
    format!("{}_{}", unix_ms(), base)
}

fn move_file(
    config_dir: &str,
    dir_name: &str,
    src: &Path,
    name: &str,
) -> Result<MovedEntry, String> {
    let dest_dir = Path::new(config_dir).join(dir_name);
    std::fs::create_dir_all(&dest_dir).map_err(|e| e.to_string())?;
    let dest = dest_dir.join(name);
    std::fs::rename(src, &dest).map_err(|e| e.to_string())?;
    Ok(MovedEntry {
        name: name.to_string(),
        path: dest.to_string_lossy().to_string(),
        original: src.to_string_lossy().to_string(),
        size_bytes: file_size(&dest),
    })
}

fn sha256(input: &str) -> String {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    format!("{:x}", hasher.finalize())
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

    #[test]
    fn trash_roundtrip() {
        let root = tmp_dir("trash");
        let config = tmp_dir("trash_cfg");
        let png_path = std::path::Path::new(&root).join("a.png");
        std::fs::write(&png_path, TINY_PNG).unwrap();
        let store = PhotoStore::new(config).unwrap();

        let p = png_path.to_string_lossy().to_string();
        store.move_to_trash(p.clone()).unwrap();
        assert!(!png_path.exists());
        let trash = store.list_trash().unwrap();
        assert_eq!(trash.len(), 1);

        store.restore_trash(trash[0].name.clone()).unwrap();
        assert!(png_path.exists());
        assert!(store.list_trash().unwrap().is_empty());

        // eliminar definitivo
        store.move_to_trash(p).unwrap();
        let trash = store.list_trash().unwrap();
        store.delete_trash_item(trash[0].name.clone()).unwrap();
        assert!(store.list_trash().unwrap().is_empty());
    }

    #[test]
    fn system_scan_skips_noise_dirs() {
        let root = tmp_dir("sys");
        let config = tmp_dir("sys_cfg");
        let store = PhotoStore::new(config.clone()).unwrap();

        let tmp = std::path::Path::new(&root);
        std::fs::create_dir_all(tmp.join("node_modules")).unwrap();
        std::fs::create_dir_all(tmp.join(".hidden")).unwrap();
        std::fs::write(tmp.join("home.png"), TINY_PNG).unwrap();
        std::fs::write(tmp.join("node_modules/junk.png"), TINY_PNG).unwrap();
        std::fs::write(tmp.join(".hidden/secret.png"), TINY_PNG).unwrap();

        let photos = store.collect_photos(tmp, true).unwrap();
        assert_eq!(photos.len(), 1);
        assert_eq!(photos[0].name, "home.png");

        // sin skip se encuentran las tres
        let all = store.collect_photos(tmp, false).unwrap();
        assert_eq!(all.len(), 3);
    }

    #[test]
    fn scan_orders_recent_first() {
        use std::time::{Duration, SystemTime};

        let root = tmp_dir("ord");
        let config = tmp_dir("ord_cfg");
        let store = PhotoStore::new(config).unwrap();

        let tmp = std::path::Path::new(&root);
        let old_path = tmp.join("old.png");
        let new_path = tmp.join("new.png");
        std::fs::write(&old_path, TINY_PNG).unwrap();
        std::fs::write(&new_path, TINY_PNG).unwrap();

        let epoch = SystemTime::UNIX_EPOCH + Duration::from_secs(0);
        let file = std::fs::OpenOptions::new()
            .write(true)
            .open(&old_path)
            .unwrap();
        file.set_modified(epoch).unwrap();
        drop(file);

        let photos = store.collect_photos(tmp, false).unwrap();
        assert_eq!(photos.len(), 2);
        assert_eq!(photos[0].name, "new.png");
        assert_eq!(photos[1].name, "old.png");
    }

    #[test]
    fn trash_moves_privates_out_of_favorites_and_albums() {
        let root = tmp_dir("trash2");
        let config = tmp_dir("trash2_cfg");
        let png_path = std::path::Path::new(&root).join("b.png");
        std::fs::write(&png_path, TINY_PNG).unwrap();
        let store = PhotoStore::new(config).unwrap();

        let p = png_path.to_string_lossy().to_string();
        store.set_favorite(p.clone(), true).unwrap();
        let album = store.create_album("A".into()).unwrap();
        store
            .add_photos_to_album(album.id, vec![p.clone()])
            .unwrap();
        store.move_to_trash(p.clone()).unwrap();

        assert!(store.favorite_paths().unwrap().is_empty());
        assert!(store.list_albums().unwrap()[0].photo_paths.is_empty());
    }

    #[test]
    fn secure_folder_and_pin() {
        let root = tmp_dir("sec");
        let config = tmp_dir("sec_cfg");
        let png_path = std::path::Path::new(&root).join("c.png");
        std::fs::write(&png_path, TINY_PNG).unwrap();
        let store = PhotoStore::new(config.clone()).unwrap();

        assert!(!store.pin_is_set().unwrap());
        store.set_pin("1234".into()).unwrap();
        assert!(store.pin_is_set().unwrap());
        assert!(store.verify_pin("1234".into()).unwrap());
        assert!(!store.verify_pin("0000".into()).unwrap());

        let p = png_path.to_string_lossy().to_string();
        store.move_to_secure(p.clone()).unwrap();
        assert!(!png_path.exists());
        let sec = store.list_secure().unwrap();
        assert_eq!(sec.len(), 1);
        store.restore_secure(sec[0].name.clone()).unwrap();
        assert!(png_path.exists());

        store.move_to_secure(p.clone()).unwrap();
        let sec = store.list_secure().unwrap();
        store.delete_secure_item(sec[0].name.clone()).unwrap();
        assert!(store.list_secure().unwrap().is_empty());
        store.clear_pin().unwrap();
        assert!(!store.pin_is_set().unwrap());
    }
}
