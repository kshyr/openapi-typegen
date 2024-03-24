mod jsdoc;

use clap::Parser;
use openapiv3::OpenAPI;
use std::path::Path;
use std::{fs, io};

const LOCAL_JSON_FILENAME: &str = "openapi.json";

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// The input OpenAPI JSON file or URL
    #[arg(short, long, default_value_t = String::from(LOCAL_JSON_FILENAME))]
    input: String,

    #[arg(short, long, default_value_t = String::from("types.js"))]
    output: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    if Path::new(&args.output).exists() {
        let mut input = String::new();
        println!(
            "File {} already exists. Do you want to overwrite it? (y/n)",
            &args.output
        );
        io::stdin()
            .read_line(&mut input)
            .expect("Failed to read line");
        if input.trim() != "y" {
            return Ok(());
        }
    }

    let openapi_json = if Path::new(&args.input).exists() {
        println!("Reading OpenAPI spec from {}", &args.input);
        read_file_to_json(&args.input)?
    } else {
        let url = &args.input;
        println!("Downloading OpenAPI JSON from {}", url);
        let response = reqwest::get(url).await?.json().await?;
        write_json_to_file(LOCAL_JSON_FILENAME, &response)?;
        response
    };

    let spec: OpenAPI = serde_json::from_value(openapi_json).expect("Failed to parse OpenAPI JSON");
    fs::write(&args.output, "").expect("Failed to write to file");

    let schemas = &spec.components.schemas;
    for (name, _) in schemas.iter() {
        jsdoc::generate_typedef(args.output.clone(), &spec, name);
    }
    println!(
        "{} JSDoc typedefs generated at {}",
        schemas.iter().count(),
        &args.output
    );
    Ok(())
}

fn read_file_to_json(filename: &str) -> Result<serde_json::Value, io::Error> {
    let binding = fs::read_to_string(filename).unwrap();
    let contents = binding.as_str();
    let json: serde_json::Value = serde_json::from_str(contents)?;
    Ok(json)
}

fn write_json_to_file(filename: &str, json: &serde_json::Value) -> Result<(), io::Error> {
    let mut file = fs::File::create(filename)?;
    serde_json::to_writer_pretty(&mut file, json)?;
    Ok(())
}
