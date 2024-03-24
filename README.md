Install:
`cargo install openapi-to-jsdoc`

`openapi-to-jsdoc -i https://api.example.com/openapi.json -o output.js`
Generates JSDoc `@typedef` for each schema found in `components.schemas`

- `-i, --input` (default: `openapi.json`) - Takes in path to file or URL to `openapi.json`
- `-i --output` (default: `types.js`) - Output file
