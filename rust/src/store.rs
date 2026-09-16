use serde::{Deserialize, Serialize};

use crate::api::Album;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MovedItem {
    pub name: String,
    pub original: String,
    /// Unix epoch (segundos) en que se movió a la papelera.
    #[serde(default)]
    pub deleted_at: u64,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct StoreData {
    pub favorite_paths: Vec<String>,
    pub albums: Vec<Album>,
    #[serde(default)]
    pub trash_items: Vec<MovedItem>,
    #[serde(default)]
    pub secure_items: Vec<MovedItem>,
    #[serde(default)]
    pub secure_pin_hash: Option<String>,
    #[serde(default)]
    pub hidden_paths: Vec<String>,
}
