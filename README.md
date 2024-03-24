Generates JSDoc `@typedef` for every schema in OpenAPI spec.

---
### Install:
`cargo install openapi-to-jsdoc`

### Usage
`openapi-to-jsdoc -i https://api.example.com/openapi.json -o output.js`

- `-i, --input` (default: `openapi.json`) - Takes in path to file or URL to `openapi.json`
- `-i --output` (default: `types.js`) - Output file
