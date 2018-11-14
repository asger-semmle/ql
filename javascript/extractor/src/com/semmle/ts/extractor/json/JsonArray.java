package com.semmle.ts.extractor.json;

import java.util.Arrays;
import java.util.Iterator;

public class JsonArray extends JsonElement implements Iterable<JsonElement> {
	private final JsonElement[] array;

	public JsonArray(JsonElement[] array) {
		this.array = array;
	}

	public JsonElement get(int i) {
		return array[i];
	}

	@Override
	public Iterator<JsonElement> iterator() {
		return Arrays.stream(array).iterator();
	}

	public int size() {
		return array.length;
	}
}
