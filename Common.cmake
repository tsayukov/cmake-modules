#[=============================================================================[
  Author: Pavel Tsayukov
  Distributed under the MIT License. See accompanying file LICENSE or
  https://opensource.org/license/mit for details.
  ------------------------------------------------------------------------------
  Include common variables and commands
  ------------------------------------------------------------------------------
  This module includes other submodules divided by subject:
  - Watchers of deprecated commands and normal variables,
    see `common/Watchers.cmake` for detais;
  - Guards, see `common/Guards.cmake` for details;
  - Project related commands, see `common/Project.cmake` for details;
  - Debugging, see `common/Debug.cmake` for details;
  - Miscellaneous, see `common/Miscellaneous.cmake` for details;

  See `Variables.cmake` to learn about existing project cached variables. That
  listfile is intended for editing existing cached variables or/and adding
  additional ones.

  Included submodules:
  - see `compiler/Common.cmake` for details;
  - see `dependencies/Common.cmake` for details;
  - see `install/Common.cmake` for details;
  - see `modules/Common.cmake` for details.
#]=============================================================================]

include_guard(GLOBAL)


#[=============================================================================[
  For internal use.
  This macro must be called at the end of the current listfile. It checks if the
  `project` command is already called, prevents in-source builds inside the
  'cmake' directory, and initialize some common commands, variables, project
  options, and project cached variables.
#]=============================================================================]
macro(__init_common)
  include("${CMAKE_CURRENT_LIST_DIR}/common/__Internal.cmake")

  # This guard should be at the beginning
  __after_project_guard()

  include("${CMAKE_CURRENT_LIST_DIR}/common/Watchers.cmake")
  include("${CMAKE_CURRENT_LIST_DIR}/common/Guards.cmake")
  include("${CMAKE_CURRENT_LIST_DIR}/common/Project.cmake")
  include("${CMAKE_CURRENT_LIST_DIR}/common/Debug.cmake")
  include("${CMAKE_CURRENT_LIST_DIR}/common/Miscellaneous.cmake")

  requires_cmake(3.14 "These modules are supported only by CMake 3.14+")

  # Init the project cached variables
  include("${CMAKE_CURRENT_LIST_DIR}/Variables.cmake")

  # Include other Commons after Variables
  include_project_module(compiler/Common)
  include_project_module(dependencies/Common)
  include_project_module(install/Common)
  include_project_module(modules/Common)

  # And these guards should be at the end
  no_in_source_builds_guard(RECURSIVE
    common
    compiler
    dependencies
    install
    modules
  )
endmacro()


########################### The end of the listfile ############################

__init_common()
