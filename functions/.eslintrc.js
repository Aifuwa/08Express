module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    // It's generally good to use a more recent ecmaVersion for modern JS features.
    // 2020 or 2021 is common for Firebase functions if you're using recent Node.js versions.
    "ecmaVersion": 2020, // Keep 2020, as Node 20 supports it well.
    "sourceType": "module", // Use 'module' for ES Modules syntax if you plan to use import/export.
    // If strictly CommonJS (require/module.exports), 'script' is fine.
    // 'module' is often safer for modern practices.
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    // --- Existing rules ---
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    // Ensure double quotes with template literal allowance
    "quotes": ["error", "double", { "allowTemplateLiterals": true }],

    // --- Added/Modified rules to address previous errors and common practices ---

    // 1. max-len: Adjust line length.
    "max-len": ["error", { "code": 140, "ignoreUrls": true, "ignoreRegExpLiterals": true, "ignoreTemplateLiterals": true }],

    // 2. object-curly-spacing: Ensures consistent spacing (e.g., { foo: 'bar' }).
    "object-curly-spacing": ["error", "always"],

    // 3. indent: Ensures consistent indentation (Google style uses 2 spaces).
    "indent": ["error", 2],

    // 4. comma-dangle: Ensures trailing commas in multi-line lists (objects, arrays, functions).
    "comma-dangle": ["error", "always-multiline"],

    // 5. semi: Google style requires semicolons. This ensures they are present.
    "semi": ["error", "always"],

    // 6. arrow-parens: Ensures parentheses around arrow function arguments (e.g., `(a) => a`).
    "arrow-parens": ["error", "always"],

    // 7. prefer-const: Enforces `const` for variables that are never reassigned.
    "prefer-const": ["error", { "destructuring": "any", "ignoreReadBeforeAssign": false }],

    // 8. no-var: Enforces `let` or `const` over `var`.
    "no-var": "error",

    // 9. eol-last: Ensures there's a newline at the end of the file.
    "eol-last": ["error", "always"],

    // 10. padded-blocks: Ensures blocks are not padded by blank lines.
    "padded-blocks": ["error", "never"],

    // 11. require-jsdoc: Disable if you don't strictly follow JSDoc for every function.
    //    Firebase functions often don't need extensive JSDoc if the name is clear.
    "require-jsdoc": "off",

    // 12. valid-jsdoc: Also disable if require-jsdoc is off.
    "valid-jsdoc": "off",

    // 13. no-trailing-spaces: Helps keep code clean.
    "no-trailing-spaces": "error",

    // 14. array-bracket-spacing: Consistent spacing for array literals.
    "array-bracket-spacing": ["error", "never"],

    // 15. space-before-function-paren: Consistent spacing for function parentheses.
    "space-before-function-paren": ["error", "never"],

    // For functions, console logs are often intentional for debugging/monitoring.
    // You might want to allow them or specifically configure for 'warn', 'error'.
    "no-console": ["warn", { "allow": ["warn", "error", "log"] }],
  },
  overrides: [
    {
      files: ["**/*.spec.*"], // Applies to test files
      env: {
        mocha: true,
      },
      rules: {
        // You might want to relax max-len for test descriptions, for example
        // "max-len": ["off"],
        "no-console": "off", // Usually allowed in tests
      },
    },
  ],
  // If you use global variables that aren't defined elsewhere (e.g., from a CDN),
  // list them here. Otherwise, leave as an empty object.
  globals: {},
};
