package com.semmle.ts.extractor;

import java.util.LinkedHashMap;
import java.util.Map;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonNull;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;

public class ParserMetadata {
	private JsonObject nodeFlags;
	private JsonObject syntaxKinds;
	private JsonArray astNodeSchemas;
	private final Map<Integer, String> nodeFlagMap = new LinkedHashMap<>();
	private final Map<Integer, String> syntaxKindMap = new LinkedHashMap<>();
	private final Map<String, Integer>[] astNodeFieldMap;

	@SuppressWarnings("unchecked")
	public ParserMetadata(JsonObject nodeFlags, JsonObject syntaxKinds, JsonArray astNodeSchemas) {
		this.nodeFlags = nodeFlags;
		this.syntaxKinds = syntaxKinds;
		this.astNodeSchemas = astNodeSchemas;
		makeEnumIdMap(nodeFlags, nodeFlagMap);
		makeEnumIdMap(syntaxKinds, syntaxKindMap);

		astNodeFieldMap = new Map[astNodeSchemas.size()];
		makeAstNodeFieldMap();
	}

	/**
	 * Builds the mapping from AST node field names to their field offsets.
	 */
	private void makeAstNodeFieldMap() {
		for (int kind = 0; kind < astNodeSchemas.size(); ++kind) {
			JsonElement elm = astNodeSchemas.get(kind);
			if (elm instanceof JsonNull)
				continue;
			JsonArray array = elm.getAsJsonArray();
			Map<String, Integer> map = astNodeFieldMap[kind] = new LinkedHashMap<String, Integer>();
			for (int field = 0; field < array.size(); ++field) {
				map.put(array.get(field).getAsString(), field);
			}
		}
	}

	/**
	 * Builds a mapping from ID to name given a TypeScript enum object.
	 */
	private void makeEnumIdMap(JsonObject enumObject, Map<Integer, String> idToName) {
		for (Map.Entry<String, JsonElement> entry : enumObject.entrySet()) {
			JsonPrimitive prim = entry.getValue().getAsJsonPrimitive();
			if (prim.isNumber() && !idToName.containsKey(prim.getAsInt())) {
				idToName.put(prim.getAsInt(), entry.getKey());
			}
		}
	}

	/**
	 * Returns the numeric value of the syntax kind enum with the given name.
	 */
	public int getSyntaxKind(String syntaxKind) {
		JsonElement descriptor = this.syntaxKinds.get(syntaxKind);
		if (descriptor == null) {
			throw new RuntimeException("Incompatible version of TypeScript installed. Missing syntax kind " + syntaxKind);
		}
		return descriptor.getAsInt();
	}

	/**
	 * Returns the name of the given syntax kind.
	 */
	public String getSyntaxKindName(int kind) {
		return this.syntaxKindMap.get(kind);
	}

	/**
	 * Returns the numeric value of the node flag with the given name.
	 */
	public int getNodeFlag(String flagName) {
		JsonElement flagDescriptor = nodeFlags.get(flagName);
		if (flagDescriptor == null) {
			throw new RuntimeException("Incompatible version of TypeScript installed. Missing node flag " + flagName);
		}
		int flagId = flagDescriptor.getAsInt();
		return flagId;
	}

	/**
	 * Returns the name of the given node flag.
	 */
	public String getNodeFlagName(int flag) {
		return this.nodeFlagMap.get(flag);
	}

	/**
	 * Returns the mapping from field names to field offsets for the given AST node
	 * kind.
	 */
	public Map<String, Integer> getAstNodeFieldMap(int kind) {
		return this.astNodeFieldMap[kind];
	}

	/**
	 * Returns the offset of the given field name in the given AST node type.
	 */
	public int getAstNodeField(int kind, String fieldName) {
		return this.astNodeFieldMap[kind].get(fieldName);
	}

	/**
	 * Returns the name of the field at the given offset in the given AST node type.
	 */
	public String getAstNodeFieldName(int kind, int field) {
		return this.astNodeSchemas.get(kind).getAsJsonArray().get(field).getAsString();
	}
}
