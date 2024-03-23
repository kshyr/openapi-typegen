#![allow(unused)]

pub enum JSDocTag {
    Typedef,
    Property,
}

#[derive(Debug)]
pub struct JSDocBuilder {
    doc: String,
}

impl JSDocBuilder {
    pub fn new() -> JSDocBuilder {
        JSDocBuilder {
            doc: String::from("/**\n"),
        }
    }

    pub fn add_line(&mut self, line: &str) {
        self.doc.push_str(" * ");
        self.doc.push_str(line);
        self.doc.push('\n');
    }

    pub fn add_tag_line(&mut self, tag: JSDocTag, line: &str) {
        self.doc.push_str(" * ");
        match tag {
            JSDocTag::Typedef => self.doc.push_str("@typedef "),
            JSDocTag::Property => self.doc.push_str("@property "),
        }
        self.doc.push_str(line);
        self.doc.push('\n');
    }

    pub fn build(&mut self) -> String {
        self.add_line("*/");
        self.doc.clone()
    }
}

mod tests {
    use super::*;

    #[test]
    fn test_basic_section() {
        let mut jsdoc = JSDocBuilder::new();
        jsdoc.add_line("This is a test");
        jsdoc.add_line("let a = 1;");
        let section = jsdoc.build();
        assert_eq!(section, "/**\n * This is a test\n * let a = 1;\n * */\n");
    }
}
