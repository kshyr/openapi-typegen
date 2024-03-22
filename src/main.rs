pub mod jsdoc_builder;
use std::fs::File;
use std::io::{self, Read};
use std::path::Path;

const FILENAME: &str = "openapi.json";

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let openapi_json = if Path::new(FILENAME).exists() {
        read_file_to_json(FILENAME)?
    } else {
        let url = std::env::var("OPENAPI_JSON_URL").unwrap();
        let response = reqwest::get(url).await?.json().await?;
        write_json_to_file(FILENAME, &response)?;
        response
    };

    let keys_array = openapi_json["components"]["schemas"].as_object().unwrap();

    println!("{:#?}", keys_array);
    Ok(())
}

fn read_file_to_json(filename: &str) -> Result<serde_json::Value, io::Error> {
    let mut file = File::open(filename)?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;
    let json: serde_json::Value = serde_json::from_str(&contents)?;
    Ok(json)
}

fn write_json_to_file(filename: &str, json: &serde_json::Value) -> Result<(), io::Error> {
    let mut file = File::create(filename)?;
    serde_json::to_writer_pretty(&mut file, json)?;
    Ok(())
}
