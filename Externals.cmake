#[=============================================================================[
  External dependencies
  ------------------------------------------------------------------------------
  Dependencies in this listfile is not related with those that are enabled
  under the developer mode. These dependencies are used directly by the current
  project and usually cannot be excluded. It's expected that this listfile will
  be included before definitions of the project targets, because some of those
  targets may link against these dependencies.
#]=============================================================================]

include_guard(GLOBAL)


include_project_module(dependencies/Docs)
if (ENABLE_DOCS)
  add_docs(docs FORMAT html
    INPUTS
      include
      README.md
  )
endif()
