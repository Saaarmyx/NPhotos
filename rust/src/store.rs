use serde::{Deserialize, Serialize};

use crate::api::Album;

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct StoreData {
    pub favorite_paths: Vec<String>,
    pub albums: Vec<Album>,
}