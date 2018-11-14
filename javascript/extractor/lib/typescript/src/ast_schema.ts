import * as ts from "./typescript";

/**
 * Maps a `ts.SyntaxKind` to the list of property names to extract for
 * that type of AST node.
 */
export let astNodeSchemas: string[][] = [];

/**
 * Properties to extract from all AST nodes.
 */
let baseSchema = [
  "kind",
  "$pos",
  "$end",
  "$type",
  "$symbol",
];

astNodeSchemas[ts.SyntaxKind.Identifier] = ["text", "escapedText"];

let functionSchema = [
  "flags",
  "modifiers",
  "decorators",
  "name",
  "type",
  "parameters",
  "typeParameters",
  "body",
  "asteriskToken",
];

astNodeSchemas[ts.SyntaxKind.CallSignature] = functionSchema;
astNodeSchemas[ts.SyntaxKind.ConstructSignature] = functionSchema;
astNodeSchemas[ts.SyntaxKind.FunctionDeclaration] = functionSchema;
astNodeSchemas[ts.SyntaxKind.FunctionExpression] = functionSchema;
astNodeSchemas[ts.SyntaxKind.GetAccessor] = functionSchema;
astNodeSchemas[ts.SyntaxKind.MethodDeclaration] = functionSchema;
astNodeSchemas[ts.SyntaxKind.SetAccessor] = functionSchema;
astNodeSchemas[ts.SyntaxKind.ConstructorType] = functionSchema;
astNodeSchemas[ts.SyntaxKind.FunctionType] = functionSchema;
astNodeSchemas[ts.SyntaxKind.IndexSignature] = functionSchema;

// Prepend the base schema to every AST node-specific schema
for (let i = 0; i < astNodeSchemas.length; ++i) {
  let schema = astNodeSchemas[i];
  if (schema != null) {
    astNodeSchemas[i] = baseSchema.concat(schema);
  }
}
