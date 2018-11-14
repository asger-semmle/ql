package com.semmle.ts.extractor.json;

import java.io.BufferedReader;
import java.io.IOException;

import com.google.gson.JsonParser;
import com.semmle.ts.extractor.ParserMetadata;
import com.semmle.util.exception.CatastrophicError;

/**
 * Reads JSON-like values from a preorder list of nodes in the tree.
 *
 * The property names to associate with a JSON object are not sent with each
 * individual object. Instead, only the kind ID of an object is sent, which is
 * then looked up in {@link ParserMetadata}.
 */
public final class PreorderJsonReader {
	private final ParserMetadata metadata;
	private final BufferedReader reader;

	public PreorderJsonReader(BufferedReader reader, ParserMetadata metadata) {
		this.reader = reader;
		this.metadata = metadata;
	}

	public JsonElement read() throws IOException {
		// The first character is a tag, indicating the type of value.
		int tag = reader.read();
		switch (tag) {
		case 'O': // object
			// The rest of the line is the numeric value of SyntaxKind of the AST node.
			int kind = Integer.parseInt(reader.readLine());
			TreeNodeType type = metadata.getTreeNodeType(kind);
			JsonElement[] values = readMultiple(type.getNumberOfFields());
			return new JsonObject(type, values);
		case 'A': // array
			int size = Integer.parseInt(reader.readLine());
			return new JsonArray(readMultiple(size));
		case 'S': // string
			return new JsonString(new JsonParser().parse(reader.readLine()).getAsString());
		case 'I': // integer
			return new JsonInt(Integer.parseInt(reader.readLine()));
		case 'B': // boolean
			return JsonBoolean.from(reader.readLine().equals("true"));
		case 'N': // null
			reader.readLine();
			return JsonNull.instance;
		case 'U':
			// Undefined or absent property (JSON.stringify does not distinguish these two
			// cases).
			// Since each object is expecting a fixed number of properties based on their
			// schema, any absent properties need to be sent explicitly.
			reader.readLine();
			return null;
		default:
			throw new CatastrophicError("Invalid preorder JSON command tag: " + (char) tag);
		}
	}

	public JsonElement[] readMultiple(int count) throws IOException {
		JsonElement[] values = new JsonElement[count];
		for (int i = 0; i < count; ++i) {
			values[i] = read();
		}
		return values;
	}
}
