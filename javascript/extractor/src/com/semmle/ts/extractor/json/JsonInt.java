package com.semmle.ts.extractor.json;

public class JsonInt extends JsonPrimitive {
	private int value;

	public JsonInt(int value) {
		this.value = value;
	}

	public boolean isInt() {
		return true;
	}

	@Override
	public int getAsInt() {
		return value;
	}
}
