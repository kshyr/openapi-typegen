mod jsdoc;
mod openapi;

use openapi::parser::OpenAPI;
use std::fs::File;
use std::io::{self, Read};
use std::path::Path;

const FILENAME: &str = "openapi.json";

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv::dotenv().ok();

    let openapi_json = if Path::new(FILENAME).exists() {
        read_file_to_json(FILENAME)?
    } else {
        let url = std::env::var("OPENAPI_JSON_URL").expect(
            "Please set the OPENAPI_JSON_URL environment variable to the URL of the OpenAPI JSON file",
        );
        let response = reqwest::get(url).await?.json().await?;
        write_json_to_file(FILENAME, &response)?;
        response
    };

    let oas = OpenAPI::from_json(openapi_json)?;
    let schemas = oas.components.unwrap().schemas;
    let schemas = schemas.into_iter().map(|(_, v)| v).collect::<Vec<_>>();
    println!("{:?}", schemas);
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
