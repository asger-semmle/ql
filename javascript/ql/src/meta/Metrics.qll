/**
 * Provides predicates for generating metrics for diagnostics purposes.
 */

private import javascript

/**
 * Gets the root folder of the snapshot.
 *
 * This is selected as the location for project-wide metrics.
 */
Folder projectRoot() { result.getRelativePath() = "" }
