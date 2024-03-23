use oas3::from_reader;
use std::io::Cursor;

pub struct OpenAPI {}

impl OpenAPI {
    pub fn from_json(json: serde_json::Value) -> Result<oas3::Spec, oas3::Error> {
        let bytes = serde_json::to_vec(&json).unwrap();
        let reader = Cursor::new(bytes);
        let oas = from_reader(reader);
        oas
    }
}
