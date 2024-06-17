include_guard(GLOBAL)


#[=============================================================================[
  This macro must be called at the end of the current listfile.
  It checks if the `project` command is already called, prevents in-source
  builds inside the 'cmake' directory, and initialize some common variables,
  project options, and project cached variables.
#]=============================================================================]
macro(init_common)
  # This guard should be at the beginning
  after_project_guard()

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
  include_project_module(config/Common)
  include_project_module(cxx_compiler/Common)
  include_project_module(dependencies/Common)
  include_project_module(modules/Common)

  # And this guard should be at the end
  no_in_source_builds_guard()
endmacro()


#################################### Guards ####################################

# Prevent including any listfiles before the `project` command
function(after_project_guard)
  if (NOT (PROJECT_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR))
    get_filename_component(file_name "${CMAKE_CURRENT_LIST_FILE}" NAME)
    message(FATAL_ERROR
      "\n"
      "'${file_name}' must be included in the current listfile after the `project` command.\n"
    )
  endif()
endfunction()

#[=============================================================================[
  Prevent in-source builds. Prefer to start each listfile with this macro.
  Although, if this project is included as a subproject, the outer project
  is allowed to build wherever it wants.
#]=============================================================================]
macro(no_in_source_builds_guard)
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
endmacro()


##################### Project related functions and macros #####################
# To prevent name clashes all project cached variables, targets, and properties
# defined by functions and macros below have a prefix followed by underscore,
# that is defined by the `define_project_namespace([<prefix>])` command.
# It is recommended to name cached variables and properties in uppercase letters
# with underscores. On the contrary, it is recommended to name targets in
# lowercase letters with underscore. The prefix, aka namespace, format is
# selected accordingly, in uppercase or lowercase letters with underscores.
# In addition, it is defined a normal variable for each project cached variable
# and target. For project cached variables, these variables are set to the value
# of the corresponding project cached variable. For project targets, these
# variables are set to the true target name.
#
# E.g. the `project_option(ENABLE_FEATURE "Enable a cool feature" ON)` command
# is trying to set an option, aka boolean cached variable, named
# `${NAMESPACE_UPPER}_ENABLE_FEATURE`. A short alias named `ENABLE_FEATURE` is
# also defined and set to `ON`.
#
# E.g. the `add_project_library(my_library INTERFACE)` command defines
# an interface library named `${namespace_lower}_my_library`. A short alias
# named `my_library` is also defined and set to the true target name.
# Typical usage: `target_compile_features(${my_library} INTERFACE cxx_std_20)`.
#
# The `EXPORT_NAME` property is also added to the target and set to `my_library`.
# It is nessecary in order to use the `install(TARGETS ${my_library} ...)` and then
# `install(EXPORT ... NAMESCAPE ${namespace_lower}::)` to export the target as
# `${namespace_lower}::my_library`.
#
# An alias target named `${namespace_lower}::my_library` is also defined.
# When a consuming project gets this project via the `find_package` command
# it uses exported targets, e.g. `${namespace_lower}::my_library`, that defined
# by the `install(EXPORT ... NAMESPACE ${namespace_lower}::)`. But if a consuming
# project gets this project via the `FetchContent` module or `add_subdirectory`
# command it has to use `my_library` until this project adds an alias defenition
# via the `add_library(${namespace_lower}::my_library ALIAS ${my_library})`
# command. Summing up, changing the method of getting this project won't cause
# to change `target_link_libraries(<consuming_target> ... <namespace>::<target>)`
# usage in any of these cases.
################################################################################

# Define the namespace, by default it is `${PROJECT_NAME}` in the appropriate
# format
function(define_project_namespace)
  if (ARGC EQUAL "0")
    set(namespace ${PROJECT_NAME})
  else()
    set(namespace ${ARGV0})
  endif()

  string(REGEX REPLACE "[- ]" "_" namespace ${namespace})

  string(TOUPPER ${namespace} namespace)
  set(NAMESPACE_UPPER ${namespace} PARENT_SCOPE)

  string(TOLOWER ${namespace} namespace)
  set(namespace_lower ${namespace} PARENT_SCOPE)
endfunction()

#[=============================================================================[
  Include the `${module}.cmake` file located in the `cmake` directory of
  the current project. It let us include cmake-files by name, preventing
  name collisions by using `include(${module})` when a module with
  the same name is defined in the outer score, e.g. the outer project
  sets its own `CMAKE_MODULE_PATH`.
#]=============================================================================]
macro(include_project_module module)
  include("${PROJECT_SOURCE_DIR}/cmake/${module}.cmake")
endmacro()

# Enable the rest of a listfile if the project variable is set
macro(enable_if_project_variable_is_set SUFFIX)
  if (NOT ${NAMESPACE_UPPER}_${SUFFIX})
    return()
  endif()
endmacro()

#[=============================================================================[
  Set a project option named `${NAMESPACE_UPPER}_${VARIABLES_ALIAS}` if there is
  no such normal or cached variable set before (see CMP0077 for details). Other
  parameters of the `option` command are passed after the `name` parameter.
  Use the short alias `${var_alias}` to get the option's value where `var_alias`
  is `${VARIABLES_ALIAS}`.
#]=============================================================================]
macro(project_option VARIABLES_ALIAS)
  option(${NAMESPACE_UPPER}_${VARIABLES_ALIAS} ${ARGN})
  set(${VARIABLES_ALIAS} ${${NAMESPACE_UPPER}_${VARIABLES_ALIAS}})
endmacro()

#[=============================================================================[
  Set a project option named `${NAMESPACE_UPPER}_${VARIABLES_ALIAS}` to `ON`
  if the developer mode is enable, e.g. by passing
  `-D${NAMESPACE_UPPER}_ENABLE_DEVELOPER_MODE=ON`.
  Note, if this project option is already set, this macro has no effect.
  Use the short alias `${var_alias}` to get the option's value where `var_alias`
  is `${VARIABLES_ALIAS}`.
#]=============================================================================]
macro(project_dev_option VARIABLES_ALIAS help_text)
  project_option(${VARIABLES_ALIAS} "${help_text}" ${ENABLE_DEVELOPER_MODE})
endmacro()

#[=============================================================================[
  Set a project cached variable named `${NAMESPACE_UPPER}_${VARIABLES_ALIAS}`
  if there is no such cached variable set before (see CMP0126 for details).
  Use the short alias `${var_alias}` to get the cached variable's value where `var_alias`
  is `${VARIABLES_ALIAS}`.
#]=============================================================================]
macro(project_cached_variable VARIABLES_ALIAS value type docstring)
  set(${NAMESPACE_UPPER}_${VARIABLES_ALIAS} ${value} CACHE ${type}
    "${docstring}" ${ARGN}
  )
  set(${VARIABLES_ALIAS} ${${NAMESPACE_UPPER}_${VARIABLES_ALIAS}})
endmacro()

# Add a project library target called `${namespace_lower}_${target_alias}`.
# All parameters of the `add_library` command are passed after `target_alias`.
macro(add_project_library target_alias)
  set(${target_alias} ${namespace_lower}_${target_alias})
  add_library(${${target_alias}} ${ARGN})
  add_library(${namespace_lower}::${target_alias} ALIAS ${${target_alias}})
  set_target_properties(${${target_alias}} PROPERTIES EXPORT_NAME ${target_alias})
endmacro()

# Add an executable target called `${namespace_lower}_${target_alias}`.
# All parameters of the `add_executable` command are passed after `target_alias`.
macro(add_project_executable target_alias)
  set(${target_alias} ${namespace_lower}_${target_alias})
  add_executable(${${target_alias}} ${ARGN})
  add_executable(${namespace_lower}::${target_alias} ALIAS ${${target_alias}})
  set_target_properties(${${target_alias}} PROPERTIES EXPORT_NAME ${target_alias})
endmacro()

macro(get_project_target_property variable target project_property)
  get_target_property("${variable}" ${target} ${NAMESPACE_UPPER}_${project_property})
endmacro()

macro(set_project_target_property target project_property value)
  set_target_properties(${target}
    PROPERTIES
      ${NAMESPACE_UPPER}_${project_property} "${value}"
  )
endmacro()

#[=============================================================================[
  Add a header only library as a project interface library.

    add_project_header_only_library(
      <target_alias> [WARNING_GUARD]
      [INCLUDE_DIR <include_dir>]
    )

  <include_dir> is the target's include directory. It is `include` by default
  and should be relative to `${PROJECT_SOURCE_DIR}` or be a subdirectory of
  `${PROJECT_SOURCE_DIR}`.

  `WARNING_GUARD` enables treating the target's include directory as system
  via passing the `SYSTEM` option to the `target_include_directories` command.
  By default, it is controlled by the `${ENABLE_TREATING_INCLUDES_AS_SYSTEM}`
  project option.
#]=============================================================================]
function(add_project_header_only_library target_alias)
  set(options WARNING_GUARD)
  set(one_value_keywords INCLUDE_DIR)
  set(multi_value_keywords "")
  cmake_parse_arguments(PARSE_ARGV 1 "args"
    "${options}"
    "${one_value_keywords}"
    "${multi_value_keywords}"
  )

  if (args_WARNING_GUARD OR ENABLE_TREATING_INCLUDES_AS_SYSTEM)
    set(warning_guard "SYSTEM")
  endif()

  if (NOT args_INCLUDE_DIR)
    set(args_INCLUDE_DIR "include")
  endif()

  if (IS_ABSOLUTE "${args_INCLUDE_DIR}")
    file(RELATIVE_PATH include_dir "${PROJECT_SOURCE_DIR}" "${args_INCLUDE_DIR}")
  elseif (EXISTS "${PROJECT_SOURCE_DIR}/${args_INCLUDE_DIR}")
    set(include_dir "${args_INCLUDE_DIR}")
  else()
    message(FATAL_ERROR
      "\"${args_INCLUDE_DIR}\" is not relative to \"${PROJECT_SOURCE_DIR}\".\n"
    )
  endif()

  add_project_library(${target_alias} INTERFACE)
  set(target ${${target_alias}})
  set(${target_alias} ${target} PARENT_SCOPE)

  target_link_libraries(${target} INTERFACE ${cxx_standard})

  target_include_directories(${target}
    ${warning_guard} INTERFACE "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/${include_dir}>"
  )
endfunction()


#################### `print` macros for debugging purposes #####################

macro(print text)
  message(STATUS "--> ${text}")
endmacro()

macro(print_var variable)
  message(STATUS "--> ${variable} = \"${${variable}}\"")
endmacro()

macro(print_var_with variable hint)
  message(STATUS "--> ${hint}: ${variable} = \"${${variable}}\"")
endmacro()


########################### The end of the listfile ############################

init_common()
