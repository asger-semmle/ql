package com.semmle.ts.extractor;

import java.util.LinkedHashMap;
import java.util.Map;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonNull;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;
import com.semmle.ts.extractor.json.TreeNodeType;

public final class ParserMetadata {
	private JsonObject nodeFlags;
	private JsonObject syntaxKinds;
	private JsonArray astNodeSchemas;
	private final Map<Integer, String> nodeFlagMap = new LinkedHashMap<>();
	private final Map<Integer, String> syntaxKindMap = new LinkedHashMap<>();
	private final TreeNodeType[] astNodeTypes;

	public ParserMetadata(JsonObject nodeFlags, JsonObject syntaxKinds, JsonArray astNodeSchemas) {
		this.nodeFlags = nodeFlags;
		this.syntaxKinds = syntaxKinds;
		this.astNodeSchemas = astNodeSchemas;
		makeEnumIdMap(nodeFlags, nodeFlagMap);
		makeEnumIdMap(syntaxKinds, syntaxKindMap);

		astNodeTypes = new TreeNodeType[astNodeSchemas.size()];
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
			Map<String, Integer> map = new LinkedHashMap<String, Integer>();
			for (int field = 0; field < array.size(); ++field) {
				map.put(array.get(field).getAsString(), field);
			}
			astNodeTypes[kind] = new TreeNodeType(getSyntaxKindName(kind), map, this);
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
	public TreeNodeType getTreeNodeType(int kind) {
		return this.astNodeTypes[kind];
	}
}
