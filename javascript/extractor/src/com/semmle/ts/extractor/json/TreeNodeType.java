package com.semmle.ts.extractor.json;

import java.util.HashMap;
import java.util.Map;

import com.semmle.ts.extractor.ParserMetadata;

public class TreeNodeType {
	private String name;
	private ParserMetadata metadata;
	private Map<String, Integer> fieldMap = new HashMap<String, Integer>();

	public TreeNodeType(String name, Map<String, Integer> fieldMap, ParserMetadata metadata) {
		this.name = name;
		this.fieldMap = fieldMap;
		this.metadata = metadata;
	}

	public String getName() {
		return name;
	}

	public int getFieldOffset(String fieldName) {
		Integer value = fieldMap.get(fieldName);
		return value == null ? -1 : value;
	}

	public int getNumberOfFields() {
		return fieldMap.size();
	}

	public ParserMetadata getMetadata() {
		return metadata;
	}
}
