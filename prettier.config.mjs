export default /** @type {import('prettier').Config} */ ({
  semi: false,
  endOfLine: "lf",
  printWidth: 100,
  quoteProps: "consistent",
  singleQuote: true,
  overrides: [
    {
      files: [".vscode/*.json"],
      options: {
        parser: "jsonc",
        quoteProps: "preserve",
        singleQuote: false,
        trailingComma: "all",
      },
    },
    {
      files: ["*.md"],
      options: {
        printWidth: 80,
      },
    },
  ],
});
