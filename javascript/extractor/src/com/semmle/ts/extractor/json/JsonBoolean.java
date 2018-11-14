package com.semmle.ts.extractor.json;

public class JsonBoolean extends JsonPrimitive {
	public static final JsonBoolean TRUE = new JsonBoolean();
	public static final JsonBoolean FALSE = new JsonBoolean();

	public static JsonBoolean from(boolean b) {
		return b ? TRUE : FALSE;
	}

	private JsonBoolean() {
	}

	@Override
	public boolean isBoolean() {
		return true;
	}

	@Override
	public boolean getAsBoolean() {
		return this == TRUE;
	}
}
