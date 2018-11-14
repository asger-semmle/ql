package com.semmle.ts.extractor.json;

public class JsonObject extends JsonElement {
	private final TreeNodeType type;
	private final JsonElement fieldValues[];

	public JsonObject(TreeNodeType type, JsonElement[] values) {
		this.type = type;
		this.fieldValues = values;
	}

	public JsonElement get(String name) {
		int offset = type.getFieldOffset(name);
		if (offset == -1) {
			throw new RuntimeException("The field '" + name + "' does not exist on AST node of type " + getTypeName());
		}
		return fieldValues[offset];
	}

	public JsonObject getAsJsonObject(String name) {
		return (JsonObject) get(name);
	}

	public JsonArray getAsJsonArray(String name) {
		return (JsonArray) get(name);
	}

	public boolean has(String name) {
		int offset = type.getFieldOffset(name);
		return offset != -1 && fieldValues[offset] != null;
	}

	public String getTypeName() {
		return type.getMetadata().getSyntaxKindName(fieldValues[0].getAsInt());
	}
}
