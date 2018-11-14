package com.semmle.ts.extractor.json;

public abstract class JsonElement {
	public JsonArray getAsJsonArray() {
		return (JsonArray) this;
	}

	public JsonObject getAsJsonObject() {
		return (JsonObject) this;
	}

	public JsonPrimitive getAsJsonPrimitive() {
		return (JsonPrimitive) this;
	}

	public String getAsString() {
		return getAsJsonPrimitive().getAsString();
	}

	public int getAsInt() {
		return getAsJsonPrimitive().getAsInt();
	}

	public boolean getAsBoolean() {
		return getAsJsonPrimitive().getAsBoolean();
	}

	public boolean isJsonArray() {
		return this instanceof JsonArray;
	}

	public boolean isBoolean() {
		return false;
	}

	public boolean isString() {
		return false;
	}

	public boolean isInt() {
		return false;
	}
}
