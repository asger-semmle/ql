import * as ts from "./typescript";

/**
 * Maps a `ts.SyntaxKind` to the list of property names to extract for
 * that type of AST node.
 */
export let astNodeSchemas: string[][] = [];

/**
 * Properties to extract from all AST nodes.
 */
export let baseSchema = [
  "kind",
  "$pos",
  "$end",
  "$type",
  "$symbol",
];

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

let callSchema = [
  "expression",
  "arguments",
  "typeArguments",
  "$resolvedSignature",
  "$overloadIndex",
];

let classSchema = [
  "modifiers",
  "decorators",
  "name",
  "typeParameters",
  "heritageClauses",
  "members",
];

let fieldSchema = [
  "modifiers",
  "decorators",
  "questionToken",
  "exclamationToken",
  "name",
  "initializer",
  "type",
];

astNodeSchemas[ts.SyntaxKind.Unknown] = [];
astNodeSchemas[ts.SyntaxKind.AnyKeyword] = [];
astNodeSchemas[ts.SyntaxKind.ArrayBindingPattern] = ["elements"];
astNodeSchemas[ts.SyntaxKind.ArrayLiteralExpression] = ["elements"];
astNodeSchemas[ts.SyntaxKind.ArrayType] = ["elementType"];
astNodeSchemas[ts.SyntaxKind.ArrowFunction] = functionSchema;
astNodeSchemas[ts.SyntaxKind.AsExpression] = ["expression", "type"];
astNodeSchemas[ts.SyntaxKind.AwaitExpression] = ["expression"];
astNodeSchemas[ts.SyntaxKind.BinaryExpression] = ["left", "right", "operatorToken"];
astNodeSchemas[ts.SyntaxKind.BindingElement] = ["name", "initializer", "dotDotDotToken", "propertyName"];
astNodeSchemas[ts.SyntaxKind.Block] = ["statements"];
astNodeSchemas[ts.SyntaxKind.BooleanKeyword] = [];
astNodeSchemas[ts.SyntaxKind.BreakStatement] = ["label"];
astNodeSchemas[ts.SyntaxKind.CallExpression] = callSchema;
astNodeSchemas[ts.SyntaxKind.CallSignature] = functionSchema;
astNodeSchemas[ts.SyntaxKind.CaseBlock] = ["clauses"];
astNodeSchemas[ts.SyntaxKind.CaseClause] = ["expression", "statements"];
astNodeSchemas[ts.SyntaxKind.CatchClause] = ["variableDeclaration", "block"];
astNodeSchemas[ts.SyntaxKind.ClassDeclaration] = classSchema;
astNodeSchemas[ts.SyntaxKind.ClassExpression] = classSchema;
astNodeSchemas[ts.SyntaxKind.CommaListExpression] = ["elements"];
astNodeSchemas[ts.SyntaxKind.ComputedPropertyName] = ["expression"];
astNodeSchemas[ts.SyntaxKind.ConditionalExpression] = ["condition", "whenTrue", "whenFalse"];
astNodeSchemas[ts.SyntaxKind.ConditionalType] = ["checkType", "extendsType", "trueType", "falseType"];
astNodeSchemas[ts.SyntaxKind.Constructor] = functionSchema;
astNodeSchemas[ts.SyntaxKind.ConstructorType] = functionSchema;
astNodeSchemas[ts.SyntaxKind.ConstructSignature] = functionSchema;
astNodeSchemas[ts.SyntaxKind.ContinueStatement] = ["label"];
astNodeSchemas[ts.SyntaxKind.DebuggerStatement] = [];
astNodeSchemas[ts.SyntaxKind.Decorator] = ["expression"];
astNodeSchemas[ts.SyntaxKind.DefaultClause] = ["expression", "statements"];
astNodeSchemas[ts.SyntaxKind.DeleteExpression] = ["expression"];
astNodeSchemas[ts.SyntaxKind.DoStatement] = ["expression", "statement"];
astNodeSchemas[ts.SyntaxKind.ElementAccessExpression] = ["expression", "argumentExpression"];
astNodeSchemas[ts.SyntaxKind.EmptyStatement] = [];
astNodeSchemas[ts.SyntaxKind.EnumDeclaration] = ["modifiers", "decorators", "name", "members"];
astNodeSchemas[ts.SyntaxKind.EnumMember] = ["name", "initializer"];
astNodeSchemas[ts.SyntaxKind.ExportAssignment] = ["isExportEquals", "expression"];
astNodeSchemas[ts.SyntaxKind.ExportDeclaration] = ["moduleSpecifier", "exportClause"];
astNodeSchemas[ts.SyntaxKind.ExportSpecifier] = ["propertyName", "name"];
astNodeSchemas[ts.SyntaxKind.ExpressionStatement] = ["expression"];
astNodeSchemas[ts.SyntaxKind.ExpressionWithTypeArguments] = ["expression", "typeArguments"];
astNodeSchemas[ts.SyntaxKind.ExternalModuleReference] = ["expression"];
astNodeSchemas[ts.SyntaxKind.FalseKeyword] = [];
astNodeSchemas[ts.SyntaxKind.ForInStatement] = ["initializer", "expression", "statement"];
astNodeSchemas[ts.SyntaxKind.ForOfStatement] = ["initializer", "expression", "statement"];
astNodeSchemas[ts.SyntaxKind.ForStatement] = ["initializer", "condition", "incrementor", "statement"];
astNodeSchemas[ts.SyntaxKind.FunctionDeclaration] = functionSchema;
astNodeSchemas[ts.SyntaxKind.FunctionExpression] = functionSchema;
astNodeSchemas[ts.SyntaxKind.FunctionType] = functionSchema;
astNodeSchemas[ts.SyntaxKind.GetAccessor] = functionSchema;
astNodeSchemas[ts.SyntaxKind.HeritageClause] = ["types", "token"];
astNodeSchemas[ts.SyntaxKind.Identifier] = ["text", "escapedText"];
astNodeSchemas[ts.SyntaxKind.IfStatement] = ["expression", "thenStatement", "elseStatement"];
astNodeSchemas[ts.SyntaxKind.ImportClause] = ["name", "namedBindings"];
astNodeSchemas[ts.SyntaxKind.ImportDeclaration] = ["moduleSpecifier", "importClause"];
astNodeSchemas[ts.SyntaxKind.ImportEqualsDeclaration] = ["name", "moduleReference"];
astNodeSchemas[ts.SyntaxKind.ImportKeyword] = [];
astNodeSchemas[ts.SyntaxKind.ImportSpecifier] = ["propertyName", "name"];
astNodeSchemas[ts.SyntaxKind.ImportType] = ["isTypeOf", "argument", "qualifier", "typeArguments"];
astNodeSchemas[ts.SyntaxKind.IndexedAccessType] = ["objectType", "indexType"];
astNodeSchemas[ts.SyntaxKind.IndexSignature] = functionSchema;
astNodeSchemas[ts.SyntaxKind.InferType] = ["typeParameter"];
astNodeSchemas[ts.SyntaxKind.InterfaceDeclaration] = ["name", "typeParameters", "members", "heritageClauses"];
astNodeSchemas[ts.SyntaxKind.IntersectionType] = ["types"];
astNodeSchemas[ts.SyntaxKind.JsxAttribute] = ["name", "initializer"];
astNodeSchemas[ts.SyntaxKind.JsxAttributes] = ["properties"];
astNodeSchemas[ts.SyntaxKind.JsxClosingElement] = ["tagName"];
astNodeSchemas[ts.SyntaxKind.JsxClosingFragment] = [];
astNodeSchemas[ts.SyntaxKind.JsxElement] = ["openingElement", "children", "closingElement"];
astNodeSchemas[ts.SyntaxKind.JsxExpression] = ["expression"];
astNodeSchemas[ts.SyntaxKind.JsxFragment] = ["openingFragmnet", "children", "closingFragment"];
astNodeSchemas[ts.SyntaxKind.JsxOpeningElement] = ["tagName", "attributes", "selfClosing"];
astNodeSchemas[ts.SyntaxKind.JsxOpeningFragment] = [];
astNodeSchemas[ts.SyntaxKind.JsxSelfClosingElement] = ["tagName", "attributes", "selfClosing"];
astNodeSchemas[ts.SyntaxKind.JsxSpreadAttribute] = ["expression"];
astNodeSchemas[ts.SyntaxKind.JsxText] = ["text"];
astNodeSchemas[ts.SyntaxKind.JsxTextAllWhiteSpaces] = ["text"];
astNodeSchemas[ts.SyntaxKind.LabeledStatement] = ["label", "statement"];
astNodeSchemas[ts.SyntaxKind.LiteralType] = ["literal"];
astNodeSchemas[ts.SyntaxKind.MappedType] = ["typeParameter", "type"];
astNodeSchemas[ts.SyntaxKind.MethodDeclaration] = functionSchema;
astNodeSchemas[ts.SyntaxKind.MethodSignature] = functionSchema;
astNodeSchemas[ts.SyntaxKind.ModuleBlock] = ["statements"];
astNodeSchemas[ts.SyntaxKind.ModuleDeclaration] = ["flags", "modifiers", "name", "body"];
astNodeSchemas[ts.SyntaxKind.NamedImports] = ["elements"];
astNodeSchemas[ts.SyntaxKind.NamedExports] = ["elements"];
astNodeSchemas[ts.SyntaxKind.NamespaceExportDeclaration] = ["name"];
astNodeSchemas[ts.SyntaxKind.NamespaceImport] = ["name"];
astNodeSchemas[ts.SyntaxKind.NeverKeyword] = [];
astNodeSchemas[ts.SyntaxKind.NewExpression] = callSchema;
astNodeSchemas[ts.SyntaxKind.NonNullExpression] = ["expression"];
astNodeSchemas[ts.SyntaxKind.NoSubstitutionTemplateLiteral] = ["text"];
astNodeSchemas[ts.SyntaxKind.NullKeyword] = [];
astNodeSchemas[ts.SyntaxKind.NumberKeyword] = [];
astNodeSchemas[ts.SyntaxKind.NumericLiteral] = ["text"];
astNodeSchemas[ts.SyntaxKind.ObjectBindingPattern] = ["elements"];
astNodeSchemas[ts.SyntaxKind.ObjectKeyword] = [];
astNodeSchemas[ts.SyntaxKind.ObjectLiteralExpression] = ["properties"];
astNodeSchemas[ts.SyntaxKind.OmittedExpression] = [];
astNodeSchemas[ts.SyntaxKind.OptionalType] = ["type"];
astNodeSchemas[ts.SyntaxKind.Parameter] = ["modifiers", "decorators", "name", "type", "dotDotDotToken", "initializer"];
astNodeSchemas[ts.SyntaxKind.ParenthesizedExpression] = ["expression"];
astNodeSchemas[ts.SyntaxKind.ParenthesizedType] = ["type"];
astNodeSchemas[ts.SyntaxKind.PostfixUnaryExpression] = ["operator", "operand"];
astNodeSchemas[ts.SyntaxKind.PrefixUnaryExpression] = ["operator", "operand"];
astNodeSchemas[ts.SyntaxKind.PropertyAccessExpression] = ["expression", "name"];
astNodeSchemas[ts.SyntaxKind.PropertyAssignment] = ["name", "initializer"];
astNodeSchemas[ts.SyntaxKind.PropertyDeclaration] = fieldSchema;
astNodeSchemas[ts.SyntaxKind.PropertySignature] = fieldSchema;
astNodeSchemas[ts.SyntaxKind.QualifiedName] = ["left", "right"];
astNodeSchemas[ts.SyntaxKind.RegularExpressionLiteral] = [];
astNodeSchemas[ts.SyntaxKind.RestType] = ["type"];
astNodeSchemas[ts.SyntaxKind.ReturnStatement] = ["expression"];
astNodeSchemas[ts.SyntaxKind.SemicolonClassElement] = [];
astNodeSchemas[ts.SyntaxKind.SetAccessor] = functionSchema;
astNodeSchemas[ts.SyntaxKind.ShorthandPropertyAssignment] = ["name"];
astNodeSchemas[ts.SyntaxKind.SourceFile] = ["statements", "parseDiagnostics", "$tokens"];
astNodeSchemas[ts.SyntaxKind.SpreadAssignment] = ["expression"];
astNodeSchemas[ts.SyntaxKind.SpreadElement] = ["expression"];
astNodeSchemas[ts.SyntaxKind.StringKeyword] = [];
astNodeSchemas[ts.SyntaxKind.StringLiteral] = ["text"];
astNodeSchemas[ts.SyntaxKind.SuperKeyword] = [];
astNodeSchemas[ts.SyntaxKind.SwitchStatement] = ["caseBlock", "expression", "clauses"];
astNodeSchemas[ts.SyntaxKind.SymbolKeyword] = [];
astNodeSchemas[ts.SyntaxKind.TaggedTemplateExpression] = ["tag", "template"];
astNodeSchemas[ts.SyntaxKind.TemplateExpression] = ["head", "templateSpans"];
astNodeSchemas[ts.SyntaxKind.TemplateHead] = ["text"];
astNodeSchemas[ts.SyntaxKind.TemplateMiddle] = ["text"];
astNodeSchemas[ts.SyntaxKind.TemplateTail] = ["text"];
astNodeSchemas[ts.SyntaxKind.TemplateSpan] = ["expression", "literal"];
astNodeSchemas[ts.SyntaxKind.ThisKeyword] = [];
astNodeSchemas[ts.SyntaxKind.ThisType] = [];
astNodeSchemas[ts.SyntaxKind.ThrowStatement] = ["expression"];
astNodeSchemas[ts.SyntaxKind.TrueKeyword] = [];
astNodeSchemas[ts.SyntaxKind.TryStatement] = ["tryBlock", "catchClause", "finallyBlock"];
astNodeSchemas[ts.SyntaxKind.TupleType] = ["elementTypes"];
astNodeSchemas[ts.SyntaxKind.TypeAliasDeclaration] = ["name", "typeParameters", "type"];
astNodeSchemas[ts.SyntaxKind.TypeAssertionExpression] = ["expression", "type"];
astNodeSchemas[ts.SyntaxKind.TypeLiteral] = ["members"];
astNodeSchemas[ts.SyntaxKind.TypeOfExpression] = ["expression"];
astNodeSchemas[ts.SyntaxKind.TypeOperator] = ["operator", "type"];
astNodeSchemas[ts.SyntaxKind.TypeParameter] = ["name", "constraint", "default"];
astNodeSchemas[ts.SyntaxKind.TypePredicate] = ["parameterName", "type"];
astNodeSchemas[ts.SyntaxKind.TypeQuery] = ["exprName"];
astNodeSchemas[ts.SyntaxKind.TypeReference] = ["typeName", "typeArguments"];
astNodeSchemas[ts.SyntaxKind.UndefinedKeyword] = [];
astNodeSchemas[ts.SyntaxKind.UnionType] = ["types"];
astNodeSchemas[ts.SyntaxKind.UnknownKeyword] = [];
astNodeSchemas[ts.SyntaxKind.VariableDeclaration] = ["name", "initializer", "type", "exclamationToken"];
astNodeSchemas[ts.SyntaxKind.VariableDeclarationList] = ["declarations", "$declarationKind"];
astNodeSchemas[ts.SyntaxKind.VariableStatement] = ["modifiers", "declarationList", "$declarationKind"];
astNodeSchemas[ts.SyntaxKind.VoidExpression] = ["expression"];
astNodeSchemas[ts.SyntaxKind.VoidKeyword] = [];
astNodeSchemas[ts.SyntaxKind.WhileStatement] = ["expression", "statement"];
astNodeSchemas[ts.SyntaxKind.WithStatement] = ["expression", "statement"];
astNodeSchemas[ts.SyntaxKind.YieldExpression] = ["expression", "asteriskToken"];

/**
 * Kinds for nodes that don't have a SyntaxKind.
 *
 * We set these kinds on non-AST nodes in the AST so they can be serialized
 * by the same mechanism as the AST itself.
 */
export const enum ExtraNodeKind {
  ParseDiagnostic = ts.SyntaxKind.Count + 1,
}

astNodeSchemas[ExtraNodeKind.ParseDiagnostic] = ["messageText"];

// Prepend the base schema to every AST node-specific schema
for (let i = 0; i < astNodeSchemas.length; ++i) {
  let schema = astNodeSchemas[i];
  if (schema != null) {
    astNodeSchemas[i] = baseSchema.concat(schema);
  }
}
