package com.semmle.ts.extractor.json;

public class JsonString extends JsonPrimitive {
	private String value;

	public JsonString(String value) {
		this.value = value;
	}

	@Override
	public boolean isString() {
		return true;
	}

	@Override
	public String getAsString() {
		return value;
	}
}
