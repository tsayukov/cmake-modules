#[=============================================================================[
  Author: Pavel Tsayukov
  Distributed under the MIT License. See accompanying file LICENSE or
  https://opensource.org/license/mit for details.
  ------------------------------------------------------------------------------
  Project related commands
  ------------------------------------------------------------------------------
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
  the project target is added to the global project property
  `${NAMESPACE}_INSTALL_PROJECT_TARGETS`. So, the `install_project_targets`
  command can be used without passed project targets.
  ------------------------------------------------------------------------------
  Command groups:
  - Project namespace:
    - define_project_namespace
  - Including
    - include_project_module
  - Project options and cached variables:
    - enable_if
    - project_option
    - project_dev_option
    - project_cached_variable
  - Project target creation:
    - add_project_library
    - add_project_executable
  - `target_*` counterparts:
    - get_project_target_name
    - project_target_compile_definitions
    - project_target_compile_features
    - project_target_compile_options
    - project_target_include_directories
    - project_target_link_directories
    - project_target_link_libraries
    - project_target_link_options
    - project_target_precompile_headers
    - project_target_sources
  - Project target properties:
    - get_project_target_property
    - set_project_target_property
  - Global project properties:
    - get_global_project_property
    - set_global_project_property
#]=============================================================================]

include_guard(GLOBAL)
__after_project_guard()


############################## Project namespace ###############################

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


################################## Including ###################################

#[=============================================================================[
  Include the `${module}.cmake` file located in the `${ROOT_CMAKE_MODULES_DIR}`
  directory of the current project. It let us include listfiles by name,
  preventing name collisions by using `include(${module})` when a module with
  the same name is defined in the outer score, e.g. the outer project sets its
  own `CMAKE_MODULE_PATH`.
#]=============================================================================]
macro(include_project_module module)
  include("${PROJECT_SOURCE_DIR}/${ROOT_CMAKE_MODULES_DIR}/${module}.cmake")
endmacro()


##################### Project options and cached variables #####################

#[=============================================================================[
  Enable the rest of a listfile if one of these conditions holds for each
  `${variable}` passed to the command:
  (a) `${variable}` has a `${NAMESPACE}::<variable-suffix>` form and
      `${NAMESPACE}_${variable}` is defined and is set to the true value;
  (b) either, there's a `${NAMESPACE}_${variable}` variable and it's set to the true
      value;
  (c) either, `${variable}` is set to the true value.
#]=============================================================================]
macro(enable_if variable)
  foreach (__variable ${variable} ${ARGN})
    if (${__variable} MATCHES "^${NAMESPACE}::")
      string(REPLACE "::" "_" __variable ${__variable})
      if (NOT ${__variable})
        return()
      endif()
    endif()
    if (DEFINED ${NAMESPACE}_${__variable})
      if (NOT ${NAMESPACE}_${__variable})
        return()
      endif()
    endif()
    if (NOT ${__variable})
      return()
    endif()
  endforeach()
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
  __compact_parse_arguments(__start_with 3
    __lists IF
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


########################### Project target creation ############################

#[=============================================================================[
  Add a project library target called by `${namespace}_${target_suffix}` with
  a `${namespace}::${target_suffix}` alias. All parameters of the `add_library`
  command are passed after `target_suffix`.

  Set the `EXPORT_NAME` and `OUTPUT_NAME` target properties to `${target_suffix}`.

  If the target is a shared library, also set the following target properties:
  - `SOVERSION` to `${PROJECT_VERSION_MAJOR}`;
  - `VERSION` to `${PROJECT_VERSION}`.

  Set the `EXCLUDE_FROM_INSTALLATION` option to exclude the target from
  installation.
#]=============================================================================]
function(add_project_library target_suffix)
  __parse_and_remove_injected_options(EXCLUDE_FROM_INSTALLATION)

  set(target ${namespace}_${target_suffix})
  add_library(${target} ${ARGN})
  add_library(${namespace}::${target_suffix} ALIAS ${target})
  set_target_properties(${target}
    PROPERTIES
      EXPORT_NAME ${target_suffix}
      OUTPUT_NAME ${target_suffix}
  )

  get_target_property(target_type ${target} TYPE)
  if (target_type STREQUAL "SHARED_LIBRARY")
    set_target_properties(${target}
      PROPERTIES
        SOVERSION ${PROJECT_VERSION_MAJOR}
        VERSION ${PROJECT_VERSION}
    )
  endif()

  if (ENABLE_INSTALL AND NOT EXCLUDE_FROM_INSTALLATION)
    append_install_project_target(${target})
  endif()
endfunction()

#[=============================================================================[
  Add an executable target called by `${namespace}_${target_suffix}` with
  a `${namespace}::${target_suffix}` alias. All parameters of
  the `add_executable` command are passed after `target_suffix`.

  Set the `EXPORT_NAME` and `OUTPUT_NAME` target properties to `${target_suffix}`.

  Set the `EXCLUDE_FROM_INSTALLATION` option to exclude the target from
  installation.
#]=============================================================================]
function(add_project_executable target_suffix)
  __parse_and_remove_injected_options(EXCLUDE_FROM_INSTALLATION)

  set(target ${namespace}_${target_suffix})
  add_executable(${target} ${ARGN})
  add_executable(${namespace}::${target_suffix} ALIAS ${target})
  set_target_properties(${target}
    PROPERTIES
      EXPORT_NAME ${target_suffix}
      OUTPUT_NAME ${target_suffix}
  )

  if (ENABLE_INSTALL AND NOT EXCLUDE_FROM_INSTALLATION)
    append_install_project_target(${target})
  endif()
endfunction()

#[=============================================================================[
  Call the `generate_export_header` command on the `<full-target-name>` under
  the hood, but also populate the `INTERFACE_INCLUDE_DIRECTORIES` and
  `INCLUDE_DIRECTORIES` target properties by `BASE_INCLUDE_DIRECTORY` parameter.
  If there's no such parameter, use the `BINARY_DIR` target property, also if
  `BASE_INCLUDE_DIRECTORY` is a relative path, add `BINARY_DIR` to it as a prefix.
  Add `BASE_INCLUDE_DIRECTORY` to the `${NAMESPACE}_EXPORT_HEADER_DIR` project
  target property, so the export header can be installed via
  the `install_project_headers` command.

  If BASE_NAME is not defined, use `<target-suffix>` by default.

  `<full-target-name>` and `<target-suffix>` is a result of calling
  the `get_project_target_name` on `${target}`.
#]=============================================================================]
function(generate_project_export_header target)
  if (NOT ENABLE_EXPORT_HEADER)
    return()
  endif()

  __parse_and_remove_injected_one_value_parameters(
  # parameters of the `generate_export_header`
    BASE_NAME
    EXPORT_FILE_NAME
  # custom parameters
    BASE_INCLUDE_DIRECTORY
  )

  get_project_target_name(${target})

  if (NOT BASE_NAME)
    set(BASE_NAME ${target_suffix})
  endif()

  get_target_property(binary_dir ${target} BINARY_DIR)

  if (NOT BASE_INCLUDE_DIRECTORY)
    set(BASE_INCLUDE_DIRECTORY "${binary_dir}")
  elseif (NOT IS_ABSOLUTE "${BASE_INCLUDE_DIRECTORY}")
    set(BASE_INCLUDE_DIRECTORY "${binary_dir}/${BASE_INCLUDE_DIRECTORY}")
  endif()

  if (NOT EXPORT_FILE_NAME)
    string(TOLOWER "${BASE_NAME}" base_name_lower)
    set(EXPORT_FILE_NAME "${binary_dir}/${base_name_lower}_export.h")
  elseif (NOT IS_ABSOLUTE "${EXPORT_FILE_NAME}")
    set(EXPORT_FILE_NAME "${BASE_INCLUDE_DIRECTORY}/${EXPORT_FILE_NAME}")
  endif()

  generate_export_header(${target}
    BASE_NAME ${BASE_NAME}
    EXPORT_FILE_NAME "${EXPORT_FILE_NAME}"
    ${ARGN}
  )

  project_target_include_directories(${target}
    PUBLIC
      "$<BUILD_INTERFACE:${BASE_INCLUDE_DIRECTORY}>"
  )

  set_project_target_property(${target}
    PROJECT_PROPERTY
      EXPORT_HEADER_DIR "${BASE_INCLUDE_DIRECTORY}"
  )
endfunction()


########################### `target_*` counterparts ############################

#[=============================================================================[
  Resolve the `${target}` and `${target_suffix}` names in the following way:
  (a) if the `${target}` has a `${namespace}::${target_suffix}` form, replace
     `::` to `_`, raise an error if there's no such target;
  (b) if there's a `${namespace}_${target}` target, use it as `target` and use
      `${target}` as `target_suffix`;
  (c) otherwise, use the ${target} as both `target` and `target_suffix`.

  Then put the final result into the `target` and `target_suffix` variables.
#]=============================================================================]
function(get_project_target_name target)
  set(target_suffix ${target})
  if ("${target}" MATCHES "^${namespace}::")
    string(REPLACE "::" "_" target ${target})
    if (NOT TARGET "${target}")
      message(FATAL_ERROR "There is no such project target \"${target}\".")
    endif()
    string(LENGTH "${namespace}_" prefix_length)
    string(SUBSTRING "${target}" 0 ${prefix_length} target_suffix)
  elseif (TARGET "${namespace}_${target}")
    set(target ${namespace}_${target})
  endif()
  set(target ${target} PARENT_SCOPE)
  set(target_suffix ${target_suffix} PARENT_SCOPE)
endfunction()

function(project_target_compile_definitions target)
  get_project_target_name(${target})
  target_compile_definitions(${target} ${ARGN})
endfunction()

function(project_target_compile_features target)
  get_project_target_name(${target})
  target_compile_features(${target} ${ARGN})
endfunction()

function(project_target_compile_options target)
  get_project_target_name(${target})
  target_compile_options(${target} ${ARGN})
endfunction()

function(project_target_include_directories target)
  get_project_target_name(${target})
  if (ENABLE_TREATING_INCLUDES_AS_SYSTEM)
    set(warning_guards "SYSTEM")
  else()
    set(warning_guards "")
  endif()
  target_include_directories(${target} ${warning_guards} ${ARGN})
endfunction()

function(project_target_link_directories target)
  get_project_target_name(${target})
  target_link_directories(${target} ${ARGN})
endfunction()

function(project_target_link_libraries target)
  get_project_target_name(${target})
  target_link_libraries(${target} ${ARGN})
endfunction()

function(project_target_link_options target)
  get_project_target_name(${target})
  target_link_options(${target} ${ARGN})
endfunction()

function(project_target_precompile_headers target)
  get_project_target_name(${target})
  target_precompile_headers(${target} ${ARGN})
endfunction()

function(project_target_sources target)
  get_project_target_name(${target})
  target_sources(${target} ${ARGN})
endfunction()


########################## Project target properties ###########################

#[=============================================================================[
  Put the value of a `<full-target-name>` target's property to a `${variable}`.
  `<full-target-name>` is a result of calling the `get_project_target_name` on
  `${target}`. The property's name is either a name passed after the `PROPERTY`
  keyword, that is, a regular target's property, or `${NAMESPACE}` prefix with
  a following underscore and a name passed after the `PROJECT_PROPERTY` keyword.

    get_project_target_property(<variable> <target>
                                (PROPERTY | PROJECT_PROPERTY) <property>)

#]=============================================================================]
function(get_project_target_property variable target)
  __compact_parse_arguments(__start_with 2
    __values
      PROPERTY
      PROJECT_PROPERTY
  )
  __only_one_of(ARGS_PROPERTY ARGS_PROJECT_PROPERTY)

  if (ARGS_PROPERTY)
    set(property ${ARGS_PROPERTY})
  elseif (ARGS_PROJECT_PROPERTY)
    set(property ${NAMESPACE}_${ARGS_PROJECT_PROPERTY})
  endif()

  get_project_target_name(${target})

  get_target_property(${variable} ${target} ${property})
  set(${variable} ${${variable}} PARENT_SCOPE)
endfunction()

#[=============================================================================[
  Set a `<full-target-name>` target's property to a `${value}`.
  `<full-target-name>` is a result of calling the `get_project_target_name` on
  `${target}`. The property's name is either a name passed after the `PROPERTY`
  keyword, that is, a regular target's property, or `${NAMESPACE}` prefix with
  a following underscore and a name passed after the `PROJECT_PROPERTY` keyword.

    set_project_target_property(<target>
                                (PROPERTY | PROJECT_PROPERTY) <property>
                                <value>)

#]=============================================================================]
function(set_project_target_property target)
  __compact_parse_arguments(__start_with 1
    __lists
      PROPERTY
      PROJECT_PROPERTY
  )
  __only_one_of(ARGS_PROPERTY ARGS_PROJECT_PROPERTY)

  if (ARGS_PROPERTY)
    __get_key_value(ARGS_PROPERTY)
    set(property ${key})
  elseif (ARGS_PROJECT_PROPERTY)
    __get_key_value(ARGS_PROJECT_PROPERTY)
    set(property ${NAMESPACE}_${key})
  endif()

  get_project_target_name(${target})
  set_target_properties(${target}
    PROPERTIES
      ${property} ${value}
  )
endfunction()


########################## Project target properties ###########################

macro(get_global_project_property variable)
  get_property(${variable} DIRECTORY "${PROJECT_SOURCE_DIR}" ${ARGN})
endmacro()

function(set_global_project_property)
  set_property(DIRECTORY "${PROJECT_SOURCE_DIR}" ${ARGN})
endfunction()
