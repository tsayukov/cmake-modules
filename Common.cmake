#[=============================================================================[
  Author: Pavel Tsayukov
  Distributed under the MIT License. See accompanying file LICENSE or
  https://opensource.org/license/mit for details.
  ------------------------------------------------------------------------------
  Include common variables and commands.
  ------------------------------------------------------------------------------
  See `Variables.cmake` to learn about existing project cached variables. That
  listfile is intended for editing existing cached variables or/and adding
  additional ones.

  Included submodules:
    * see `compiler/Common.cmake` for details
    * see `dependencies/Common.cmake` for details
    * see `install/Common.cmake` for details
    * see `modules/Common.cmake` for details

  Commands:
    * Guards:
      - no_in_source_builds_guard
      - requires_cmake
    * Watchers:
      - mark_command_as_deprecated (3.18+, see details)
      - mark_normal_variable_as_deprecated
    * Project related commands:
      - define_project_namespace
      - include_project_module
      - enable_if_project_variable_is_set
      - project_option
      - project_dev_option
      - project_cached_variable
      - add_project_library
      - add_project_executable
      - get_project_target_property
      - set_project_target_property
      - project_target_compile_definitions
      - project_target_compile_features
      - project_target_compile_options
      - project_target_include_directories
      - project_target_link_directories
      - project_target_link_libraries
      - project_target_link_options
      - project_target_precompile_headers
      - project_target_sources
    * Host information
      - get_n_physical_cores
      - get_n_logical_cores
    * Miscellaneous
      - xor
    * Debugging
      - print
      - print_var
      - print_var_with
      - create_symlink_to_compile_commands

  Usage:

  # File: CMakeLists.txt
    cmake_minimum_required(VERSION 3.14 FATAL_ERROR)
    project(my_project_name CXX)

    include("${PROJECT_SOURCE_DIR}/cmake/Common.cmake")
    no_in_source_builds_guard()

    # Next, see compiler/Common.cmake usage

#]=============================================================================]

include_guard(GLOBAL)


#[=============================================================================[
  For internal use: this macro must be called at the end of the current listfile.
  It checks if the `project` command is already called, prevents in-source
  builds inside the 'cmake' directory, and initialize some common variables,
  project options, and project cached variables.
#]=============================================================================]
macro(__init_common)
  # This guard should be at the beginning
  __after_project_guard()

  if(CMAKE_VERSION LESS "3.14")
    message(FATAL_ERROR
      "Requires a CMake version not lower than 3.14, but got ${CMAKE_VERSION}."
    )
  endif()

  #[===========================================================================[
    The `PROJECT_IS_TOP_LEVEL` is set by the `project` command in CMake 3.21+.
    Otherwise, the custom version of that variable is used that works
    in the same way as described in the `PROJECT_IS_TOP_LEVEL` documentation.
    See: https://cmake.org/cmake/help/latest/variable/PROJECT_IS_TOP_LEVEL.html
  #]===========================================================================]
  if (CMAKE_VERSION LESS "3.21")
    string(COMPARE EQUAL
      "${CMAKE_SOURCE_DIR}" "${PROJECT_SOURCE_DIR}"
      PROJECT_IS_TOP_LEVEL
    )
  endif()

  # Init the project cached variables
  include_project_module(Variables)

  # Include other Commons after Variables
  include_project_module(compiler/Common)
  include_project_module(dependencies/Common)
  include_project_module(install/Common)
  include_project_module(modules/Common)

  # And this guard should be at the end
  no_in_source_builds_guard()
endmacro()


#################################### Guards ####################################

# For internal use: prevent including any listfiles before the `project` command
# in the current project root listfile.
function(__after_project_guard)
  if (NOT PROJECT_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    get_filename_component(file_name "${CMAKE_CURRENT_LIST_FILE}" NAME)
    message(FATAL_ERROR
      "'${file_name}' must be included in the current listfile after the `project` command."
    )
  endif()
endfunction()

#[=============================================================================[
  Prevent in-source builds. Prefer to start each listfile with this function.
  Although, if this project is included as a subproject, the outer project
  is allowed to build wherever it wants.
#]=============================================================================]
function(no_in_source_builds_guard)
  if (PROJECT_IS_TOP_LEVEL AND (CMAKE_CURRENT_LIST_DIR STREQUAL CMAKE_BINARY_DIR))
    message(FATAL_ERROR
      "\n"
      "In-source builds are not allowed. Instead, provide a path to build tree like so:\n"
      "cmake -B <binary-directory>\n"
      "Or use presets with an out-of-source build configuration like so:\n"
      "cmake --preset <preset-name>\n"
      "To remove files you accidentally created execute:\n"
      "NOTE: be careful if you had you own directory and files with same names! Use your version control system to restore your data.\n"
      "Linux: rm -rf CMakeFiles CMakeCache.txt cmake_install.cmake\n"
      "Windows (PowerShell): Remove-Item CMakeFiles, CMakeCache.txt, cmake_install.cmake -force -recurse\n"
      "Windows (Command Prompt): rmdir CMakeFiles /s /q && del /q CMakeCache.txt cmake_install.cmake\n"
      "NOTE: Build generator files may also remain, that is, 'Makefile', 'build.ninja' and so forth.\n"
    )
  endif()
endfunction()

#[=============================================================================[
  Check if CMake's version is not less than ${version}, otherwise, print
  the error message with ${reason}. It may be useful if building in the
  developer mode needs higher CMake's version than building to only install
  the project.
#]=============================================================================]
function(requires_cmake version reason)
  if (CMAKE_VERSION VERSION_LESS "${version}")
    message(FATAL_ERROR
      "CMake ${version}+ is required because of the reason \"${reason}\", but the current version is ${CMAKE_VERSION}."
    )
  endif()
endfunction()


################################### Watchers ###################################

#[=============================================================================[
  For CMake version 3.18+, mark the `${command}` command as deprecated because
  of "${reason}".
  For earlier versions, a corresponding macro should be written manually after
  each definition of a deprecated command:

    # E.g. `foo` is a deprecated command now
    macro(foo)
      message(DEPRECATION "The `foo` command is deprecated.")
      _foo(${ARGV})
    endmacro()

#]=============================================================================]
macro(mark_command_as_deprecated command reason)
  cmake_language(EVAL CODE "
    macro(${command})
      message(DEPRECATION \"The `${command}` command is deprecated because of: ${reason}.\")
      _${command}(" [=[ ${ARGV} ]=] ")
    endmacro()"
  )
endmacro()

#[=============================================================================[
  Mark the `${variable}` normal variable as deprecated because of "${reason}".
  Even though this macro can be used only for normal variables, since all
  project cached variables have aliases, these aliases can be used as normal
  variables in this macro.
#]=============================================================================]
macro(mark_normal_variable_as_deprecated variable reason)
  function(__watcher_deprecated_${variable} variable access)
    if (access STREQUAL "READ_ACCESS")
      message(DEPRECATION "The `${variable}` normal variable is deprecated because of: ${reason}")
    endif()
  endfunction()

  variable_watch(${variable} __watcher_deprecated_${variable})
endmacro()


################################################################################
#[=============================================================================[
                            Project related commands

  To prevent name clashes all project cached variables, targets, and properties
  defined by functions and macros below have a prefix followed by underscore.
  This prefix is defined by the `define_project_namespace([<prefix>])` command.
  It is recommended to name cached variables and properties in uppercase letters
  with underscores. On the contrary, it is recommended to name targets in
  lowercase letters with underscore. The prefix, aka namespace, format is
  selected accordingly, in uppercase or lowercase letters with underscores.
  In addition, normal variables are defined for all project cached variables as
  short aliases. These variables are set to the value of the corresponding
  project cached variable.

  E.g. the `project_option(ENABLE_FEATURE "Enable a cool feature" ON)` command
  is trying to set an option, aka boolean cached variable, named by
  `${NAMESPACE}_ENABLE_FEATURE`. A short alias named by `ENABLE_FEATURE`
  is also defined and set to `ON`.

  E.g. the `add_project_library(my_library INTERFACE)` command defines
  an interface library named by `${namespace}_my_library`. To use the short
  alias `my_library`, use `project_target_*` commands (see below) and pass it to
  them instead of the full target name. Typical usage:

    project_target_link_libraries(my_library INTERFACE another_library)

  All `target_*` commands have `project_target_*` counterparts. They take some
  `${target}` name and resolve it in the following way:
    (a) if the `${target}` has a `${namespace}::<target_suffix>` form, replace
    `::` to `_`, raise an error if there's no such target;
    (b) if there's a `${namespace}_${target}` target, use it;
    (c) otherwise, use the ${target}.

  Let's say we define a project target named by `${namespace}_my_library`.
  The `EXPORT_NAME` property is also added to the target and set to `my_library`.
  It is nessecary in order to use the command below to export the target as
  `${namespace}::my_library`:

    install(TARGETS ${namespace}_my_library ...)
    install(EXPORT ... NAMESCAPE ${namespace}::)

  An alias target named by `${namespace}::my_library` is also defined.
  When a consuming project gets this project via the `find_package` command
  it uses exported targets, e.g. `${namespace}::my_library`, that defined
  by `install(EXPORT ... NAMESPACE ${namespace}::)`.
  But if a consuming project gets this project via the `FetchContent` module or
  `add_subdirectory` command it has to use `${namespace}_my_library` until this
  project adds an alias defenition:

    add_library(${namespace}::my_library ALIAS ${namespace}_my_library)

  Summing up, changing the method of getting this project won't cause
  to change the command usage below in any of these cases:

    `target_link_libraries(<consuming_target> ... ${namespace}::my_library)`

  If `${NAMESPACE}_ENABLE_INSTALL` is enabled and a project target is not
  excluded from installation manually (see `add_project_*` for details),
  the project target is added to the `${PROJECT_SOURCE_DIR}` directory property
  `${NAMESPACE}_INSTALL_PROJECT_TARGETS`. So, the `install_project_targets`
  command can be used without passed project targets.
#]=============================================================================]

# Define the namespace, by default it is `${PROJECT_NAME}` in the appropriate
# format, see `NAMESPACE` and `namespace` variables.
function(define_project_namespace)
  if (ARGC EQUAL "0")
    set(namespace ${PROJECT_NAME})
  else()
    set(namespace ${ARGV0})
  endif()

  string(REGEX REPLACE "[- ]" "_" namespace ${namespace})

  string(TOUPPER ${namespace} namespace)
  set(NAMESPACE ${namespace} PARENT_SCOPE)

  string(TOLOWER ${namespace} namespace)
  set(namespace ${namespace} PARENT_SCOPE)
endfunction()

#[=============================================================================[
  Include the `${module}.cmake` file located in the `cmake` directory of
  the current project. It let us include listfiles by name, preventing
  name collisions by using `include(${module})` when a module with
  the same name is defined in the outer score, e.g. the outer project
  sets its own `CMAKE_MODULE_PATH`.
#]=============================================================================]
macro(include_project_module module)
  include("${PROJECT_SOURCE_DIR}/cmake/${module}.cmake")
endmacro()

# Enable the rest of a listfile if the project cached variable is set
macro(enable_if_project_variable_is_set variable_suffix)
  if (NOT ${NAMESPACE}_${variable_suffix})
    return()
  endif()
endmacro()

#[=============================================================================[
  Set a project option named `${NAMESPACE}_${variable_alias}` if there is no
  such normal or cached variable set before (see CMP0077 for details). Other
  parameters of the `option` command are passed after the `variable_alias`
  parameter, except that the `value` parameter is required now.
  Use the short alias `${ALIAS}` to get the option's value where `ALIAS` is
  `${variable_alias}`.

    project_option(<variable_alias> "<help_text>" <value> [IF <condition>])

  The `condition` parameter after the `IF` keyword is a condition that is used
  inside the `if (<condition>)` command. If it is true, the project option will
  try to set to `${value}`, otherwise, to the opposite one.
#]=============================================================================]
function(project_option variable_alias help_text value)
  set(options "")
  set(one_value_keywords "")
  set(multi_value_keywords IF)
  cmake_parse_arguments(PARSE_ARGV 3 "ARGS"
    "${options}"
    "${one_value_keywords}"
    "${multi_value_keywords}"
  )

  set(variable ${NAMESPACE}_${variable_alias})

  if (value)
    set(not_value OFF)
  else()
    set(not_value ON)
  endif()

  if (DEFINED ARGS_IF)
    if (${ARGS_IF})
      option(${variable} "${help_text}" ${value})
    else()
      option(${variable} "${help_text}" ${not_value})
    endif()
  else()
    option(${variable} "${help_text}" ${value})
  endif()

  set(${variable_alias} ${${variable}} PARENT_SCOPE)
endfunction()

#[=============================================================================[
  Set a project option named by `${NAMESPACE}_${variable_alias}` to `ON`
  if the developer mode is enable, e.g. by passing
  `-D${NAMESPACE}_ENABLE_DEVELOPER_MODE=ON`.
  Note, if this project option is already set, this macro has no effect.
  Use the short alias `${ALIAS}` to get the option's value where `ALIAS`
  is `${variable_alias}`.
#]=============================================================================]
macro(project_dev_option variable_alias help_text)
  project_option(${variable_alias} "${help_text}" ${ENABLE_DEVELOPER_MODE})
endmacro()

#[=============================================================================[
  Set a project cached variable named by `${NAMESPACE}_${variable_alias}`
  if there is no such cached variable set before (see CMP0126 for details).
  Use the short alias `${ALIAS}` to get the cached variable's value where
  `ALIAS` is `${variable_alias}`.
#]=============================================================================]
function(project_cached_variable variable_alias value type docstring)
  set(${NAMESPACE}_${variable_alias} ${value} CACHE ${type}
    "${docstring}" ${ARGN}
  )
  set(${variable_alias} ${${NAMESPACE}_${variable_alias}} PARENT_SCOPE)
endfunction()

#[=============================================================================[
  Add a project library target called by `${namespace}_${target_suffix}`.
  All parameters of the `add_library` command are passed after `target_suffix`.
  Set the `EXCLUDE_FROM_INSTALLATION` option to exclude the target from
  installation.
#]=============================================================================]
function(add_project_library target_suffix)
  set(options EXCLUDE_FROM_INSTALLATION)
  set(one_value_keywords "")
  set(multi_value_keywords "")
  cmake_parse_arguments(PARSE_ARGV 1 "ARGS"
    "${options}"
    "${one_value_keywords}"
    "${multi_value_keywords}"
  )

  set(target ${namespace}_${target_suffix})
  add_library(${target} ${ARGN})
  add_library(${namespace}::${target_suffix} ALIAS ${target})
  set_target_properties(${target} PROPERTIES EXPORT_NAME ${target_suffix})

  if (ENABLE_INSTALL AND NOT ARGS_EXCLUDE_FROM_INSTALLATION)
    append_install_project_target(${target})
  endif()
endfunction()

#[=============================================================================[
  Add an executable target called by `${namespace}_${target_suffix}`.
  All parameters of the `add_executable` command are passed after `target_suffix`.
  Set the `EXCLUDE_FROM_INSTALLATION` option to exclude the target from
  installation.
#]=============================================================================]
function(add_project_executable target_suffix)
  set(options EXCLUDE_FROM_INSTALLATION)
  set(one_value_keywords "")
  set(multi_value_keywords "")
  cmake_parse_arguments(PARSE_ARGV 1 "ARGS"
    "${options}"
    "${one_value_keywords}"
    "${multi_value_keywords}"
  )

  set(target ${namespace}_${target_suffix})
  add_executable(${target} ${ARGN})
  add_executable(${namespace}::${target_suffix} ALIAS ${target})
  set_target_properties(${target} PROPERTIES EXPORT_NAME ${target_suffix})

  if (ENABLE_INSTALL AND NOT ARGS_EXCLUDE_FROM_INSTALLATION)
    append_install_project_target(${target})
  endif()
endfunction()

macro(get_project_target_property variable target project_property)
  get_target_property("${variable}" ${target} ${NAMESPACE}_${project_property})
endmacro()

macro(set_project_target_property target project_property value)
  set_target_properties(${target}
    PROPERTIES
      ${NAMESPACE}_${project_property} "${value}"
  )
endmacro()

function(__get_project_target_name target)
  if ("${target}" MATCHES "^${namespace}::")
    string(REPLACE "::" "_" target ${target})
    if (NOT TARGET "${target}")
      message(FATAL_ERROR "There is no such project target \"${target}\".")
    endif()
  elseif (TARGET "${namespace}_${target}")
    set(target ${namespace}_${target})
  endif()
  set(target ${target} PARENT_SCOPE)
endfunction()

function(project_target_compile_definitions target)
  __get_project_target_name(${target})
  target_compile_definitions(${target} ${ARGN})
endfunction()

function(project_target_compile_features target)
  __get_project_target_name(${target})
  target_compile_features(${target} ${ARGN})
endfunction()

function(project_target_compile_options target)
  __get_project_target_name(${target})
  target_compile_options(${target} ${ARGN})
endfunction()

function(project_target_include_directories target)
  __get_project_target_name(${target})
  if (ENABLE_TREATING_INCLUDES_AS_SYSTEM)
    set(warning_guards "SYSTEM")
  else()
    set(warning_guards "")
  endif()
  target_include_directories(${target} ${warning_guards} ${ARGN})
endfunction()

function(project_target_link_directories target)
  __get_project_target_name(${target})
  target_link_directories(${target} ${ARGN})
endfunction()

function(project_target_link_libraries target)
  __get_project_target_name(${target})
  target_link_libraries(${target} ${ARGN})
endfunction()

function(project_target_link_options target)
  __get_project_target_name(${target})
  target_link_options(${target} ${ARGN})
endfunction()

function(project_target_precompile_headers target)
  __get_project_target_name(${target})
  target_precompile_headers(${target} ${ARGN})
endfunction()

function(project_target_sources target)
  __get_project_target_name(${target})
  target_sources(${target} ${ARGN})
endfunction()

############################### Host information ###############################

# Use the `n_physical_cores` variable to get the number of physical processor
# cores after calling this macro
macro(get_n_physical_cores)
  cmake_host_system_information(RESULT n_physical_cores QUERY NUMBER_OF_PHYSICAL_CORES)
endmacro()

# Use the `n_logical_cores` variable to get the number of logical processor
# cores after calling this macro
macro(get_n_logical_cores)
  cmake_host_system_information(RESULT n_logical_cores QUERY NUMBER_OF_LOGICAL_CORES)
endmacro()


################################ Miscellaneous #################################

# Exclusive OR. Use the `xor_result` variable to get the result.
function(xor lhs rhs)
  if (((NOT "${lhs}") AND "${rhs}") OR ("${lhs}" AND (NOT "${rhs}")))
    set(xor_result ON PARENT_SCOPE)
  else()
    set(xor_result OFF PARENT_SCOPE)
  endif()
endfunction()


################################## Debugging ###################################

macro(print text)
  message("${text}")
endmacro()

macro(print_var variable)
  message("${variable} = \"${${variable}}\"")
endmacro()

macro(print_var_with variable hint)
  message("${hint}: ${variable} = \"${${variable}}\"")
endmacro()

#[=============================================================================[
  Create a symbolic link in `${PROJECT_SOURCE_DIR}/build/` directory to
  `compile_commands.json` if `${PROJECT_SOURCE_DIR}/build/` itself is not
  the project binary directory.
#]=============================================================================]
function(create_symlink_to_compile_commands)
  if (NOT PROJECT_BINARY_DIR STREQUAL "${PROJECT_SOURCE_DIR}/build")
    file(MAKE_DIRECTORY "${PROJECT_SOURCE_DIR}/build")
    execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink
      "${PROJECT_BINARY_DIR}/compile_commands.json"
      "${PROJECT_SOURCE_DIR}/build/compile_commands.json"
    )
  endif()
endfunction()


########################### The end of the listfile ############################

__init_common()
