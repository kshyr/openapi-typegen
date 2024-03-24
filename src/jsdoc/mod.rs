use std::fs;

use openapiv3::{OpenAPI, RefOr, SchemaKind, Type};

pub mod builder;

pub fn generate_typedef(file: String, spec: &OpenAPI, schema_name: &str) -> String {
    let mut jsdoc = builder::JSDocBuilder::new();
    let schema = spec
        .components
        .schemas
        .get(schema_name)
        .expect("Schema not found")
        .as_item() // This is safe because we know the schema exists and it's not a reference
        .unwrap();

    jsdoc.add_tag_line(
        builder::JSDocTag::Typedef,
        &format!("{{Object}} {}", schema_name),
    );

    for (prop_name, prop) in schema.properties() {
        let prop_type = match prop {
            RefOr::Reference { reference } => reference
                .strip_prefix("#/components/schemas/")
                .unwrap()
                .to_string(),
            RefOr::Item(item) => match &item.kind {
                SchemaKind::Type(t) => match t {
                    Type::String(_) => "string".to_string(),
                    Type::Number(_) => "number".to_string(),
                    Type::Integer(_) => "number".to_string(),
                    Type::Boolean {} => "boolean".to_string(),
                    Type::Object(_) => "Object".to_string(),
                    Type::Array(array) => {
                        let item = *array.items.clone().unwrap();
                        let item_type: String = match item {
                            RefOr::Reference { reference } => {
                                let mut reference = reference
                                    .strip_prefix("#/components/schemas/")
                                    .unwrap()
                                    .to_string();
                                reference.push_str("[]");
                                reference
                            }
                            RefOr::Item(item) => match &item.kind {
                                SchemaKind::Type(t) => match t {
                                    Type::String(_) => "string[]".to_string(),
                                    Type::Number(_) => "number[]".to_string(),
                                    Type::Integer(_) => "number[]".to_string(),
                                    Type::Boolean {} => "boolean[]".to_string(),
                                    Type::Object(_) => "Object[]".to_string(),
                                    _ => todo!(),
                                },
                                _ => todo!(),
                            },
                        };
                        item_type
                    }
                },
                _ => todo!(),
            },
        };

        let prop_name = if schema.get_required().unwrap().contains(prop_name) {
            prop_name.to_string()
        } else {
            format!("[{}]", prop_name)
        };

        jsdoc.add_tag_line(
            builder::JSDocTag::Property,
            &format!("{{{}}} {}", prop_type, prop_name),
        );
    }
    if fs::File::open(&file).is_err() {
        fs::write(&file, "").unwrap();
    }
    let file_contents = fs::read_to_string(&file).unwrap();
    let doc = format!("{}\n{}", &file_contents, jsdoc.build().as_str());
    fs::write(file, &doc).unwrap();
    doc
}
