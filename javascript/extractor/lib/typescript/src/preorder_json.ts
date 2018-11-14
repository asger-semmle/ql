import * as ts from "./typescript";
import { astNodeSchemas } from "./ast_schema";

type Enumerator = (obj: object, cb: (value: any) => void) => void;
let precompiledEnumerators: Enumerator[] = [];
precompiledEnumerators.length = astNodeSchemas.length;
for (let i = 0; i < astNodeSchemas.length; ++i) {
  let properties = astNodeSchemas[i];
  if (properties == null) {
    continue;
  }
  precompiledEnumerators[i] = <Enumerator> new Function(
      "obj",
      "cb",
      properties.map(prop => `cb(obj.${prop});`).join("\n"));
}

export function stringify(value: any): string {
  let result = "";
  visit(value);
  return result;

  function visit(value: any) {
    if (value instanceof Array) {
      result += ("A" + value.length) + "\n";
      for (let i = 0, len = value.length; i < len; ++i) {
        visit(value[i]);
      }
    } else if (value == null) {
      result += ( value === undefined ? "U" : "N") + "\n";
    } else if (typeof value === "object") {
      let kind = value.kind;
      let enumerator = precompiledEnumerators[kind];
      if (enumerator == null) {
        kind = ts.SyntaxKind.Unknown;
        enumerator = precompiledEnumerators[0];
      }
      result += ("O" + kind) + "\n";
      enumerator(value, visit);
    } else if (typeof value === "number") {
      result += ("I" + value) + "\n";
    } else if (typeof value === "boolean") {
      result += ("B" + value) + "\n";
    } else if (typeof value === "string") {
      result += ("S" + JSON.stringify(value)) + "\n";
    } else {
      throw new Error("Cannot serialize value: " + JSON.stringify(value));
    }
  }
}
