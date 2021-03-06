/**
 * @name Unresolved import
 * @description An unresolved import may result in reduced coverage and accuracy of analysis.
 * @kind problem
 * @problem.severity info
 * @id py/import-failure
 */

import python

ImportExpr alternative_import(ImportExpr ie) {
    exists(Alias thisalias, Alias otheralias |
        (thisalias.getValue() = ie or ((ImportMember)thisalias.getValue()).getModule() = ie)
        and
        (otheralias.getValue() = result or ((ImportMember)otheralias.getValue()).getModule() = result)
        and
        (
            exists(If i | i.getBody().contains(ie) and i.getOrelse().contains(result)) or
            exists(If i | i.getBody().contains(result) and i.getOrelse().contains(ie)) or
            exists(Try t | t.getBody().contains(ie) and t.getAHandler().contains(result)) or
            exists(Try t | t.getBody().contains(result) and t.getAHandler().contains(ie))
        )
    )
}

string os_specific_import(ImportExpr ie) {
    exists(string name | name = ie.getImportedModuleName() |
        name.matches("org.python.%") and result = "java"
        or
        name.matches("java.%") and result = "java"
        or
        name.matches("Carbon.%") and result = "darwin"
        or
        result = "win32" and (
            name = "_winapi" or name = "_win32api" or name = "_winreg" or
            name = "nt" or name.matches("win32%") or name = "ntpath"
        )
        or
        result = "linux2" and (
            name = "posix" or name = "posixpath"
        )
        or
        result = "unsupported" and (
            name = "__pypy__" or name = "ce" or name.matches("riscos%")

        )
    )
}

string get_os() {
    py_flags_versioned("sys.platform", result, major_version().toString())
}

predicate ok_to_fail(ImportExpr ie) {
     alternative_import(ie).refersTo(_)
     or
     os_specific_import(ie) != get_os()
}

from ImportExpr ie
where not ie.refersTo(_) and
      exists(Context c | c.appliesTo(ie.getAFlowNode())) and
      not ok_to_fail(ie)  and
      not exists(VersionGuard guard |
          if guard.isTrue() then
              guard.controls(ie.getAFlowNode().getBasicBlock(), false)
          else
              guard.controls(ie.getAFlowNode().getBasicBlock(), true)
      )

select ie, "Unable to resolve import of '" + ie.getImportedModuleName() + "'."
