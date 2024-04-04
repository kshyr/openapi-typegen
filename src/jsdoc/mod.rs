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
                SchemaKind::Type(t) => get_prop_type(t),
                SchemaKind::OneOf { one_of } => {
                    // union type
                    let mut union = String::new();
                    for (i, item) in one_of.iter().enumerate() {
                        let item_type = get_item_type(item);
                        let union_sign = if i == one_of.len() - 1 { "" } else { " | " };
                        union.push_str(format!("{} {}", item_type, union_sign).as_str());
                    }
                    union
                }
                SchemaKind::AllOf { all_of } => {
                    let mut intersection = String::new();
                    for (i, item) in all_of.iter().enumerate() {
                        let item_type = get_item_type(item);
                        let union_sign = if i == all_of.len() - 1 { "" } else { " & " };
                        intersection.push_str(format!("{}{}", item_type, union_sign).as_str());
                    }
                    intersection
                }
                SchemaKind::AnyOf { any_of } => {
                    println!(" AnyOf {:?}", any_of);
                    "Object".to_string()
                }

                SchemaKind::Not { not } => {
                    println!("Not {:?}", not);
                    "Object".to_string()
                }
                SchemaKind::Any(_) => {
                    println!("Any");
                    "Object".to_string()
                }
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

fn get_item_type(item: &RefOr<openapiv3::Schema>) -> String {
    match item {
        RefOr::Reference { reference } => reference
            .strip_prefix("#/components/schemas/")
            .unwrap()
            .to_string(),
        RefOr::Item(item) => match &item.kind {
            SchemaKind::Type(t) => get_prop_type(t),
            _ => todo!(),
        },
    }
}

fn get_prop_type(t: &Type) -> String {
    match t {
        Type::String(s) => {
            let enum_array = s
                .enumeration
                .iter()
                .map(|x| format!(r#""{}""#, x))
                .filter(|x| !x.is_empty())
                .collect();
            if let Some(en) = get_enum_type(&enum_array) {
                return en;
            }
            println!("String {:?}", s);
            "string".to_string()
        }
        Type::Number(n) => {
            let enum_array = n
                .enumeration
                .iter()
                .map(|x| {
                    if let Some(n_inner) = x {
                        n_inner.to_string()
                    } else {
                        "".to_string()
                    }
                })
                .filter(|x| !x.is_empty())
                .collect();
            if let Some(en) = get_enum_type(&enum_array) {
                en
            } else {
                "number".to_string()
            }
        }
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
    }
}

fn get_enum_type(enums: &Vec<String>) -> Option<String> {
    if enums.is_empty() {
        return None;
    }

    let mut enum_type = String::new();
    for (i, value) in enums.iter().enumerate() {
        let union_sign = if i == enums.len() - 1 { "" } else { " | " };
        enum_type.push_str(format!("{}{}", value, union_sign).as_str());
    }
    Some(enum_type)
}
