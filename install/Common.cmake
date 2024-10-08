#[=============================================================================[
  Author: Pavel Tsayukov
  Distributed under the MIT License. See accompanying file LICENSE or
  https://opensource.org/license/mit for details.
  ------------------------------------------------------------------------------
  Installation commands
  ------------------------------------------------------------------------------
  Commands:
  - Installation:
    - install_project_cmake_configs
    - install_project_license
    - install_project_headers
    - install_project_targets
  - Auxiliary commands:
    - add_component_target
    - append_install_project_target
    - get_install_project_targets
#]=============================================================================]

include_guard(GLOBAL)
__variable_init_guard()


enable_if(ENABLE_INSTALL)

# Helper functions for creating config files that can be included by other
# projects to find and use a package.
# See: https://cmake.org/cmake/help/latest/module/CMakePackageConfigHelpers.html
include(CMakePackageConfigHelpers)


############################# Installation commands ############################

#[=============================================================================[
  Create and install CMake configuration files for using the `find_package`
  command.

    install_project_cmake_configs(
      [PATH_VARS <var1> <var2> ... <varN>]
      [NO_SET_AND_CHECK_MACRO]
      [NO_CHECK_REQUIRED_COMPONENTS_MACRO]
      [VERSION <major.minor.patch>]
      COMPATIBILITY <version_compatibility>
      [ARCH_INDEPENDENT]
    )

  This function internally calls the `configure_package_config_file`,
  `write_basic_package_version_file`, and `install(FILES)` commands. Some of
  the parameters of these commands may be passed to this function.

  `INSTALL_DESTINATION` is always `${INSTALL_CMAKE_DIR}`, see the project
  variables in `cmake/Variables.cmake`. `INSTALL_CMAKE_DIR` is also appended to
  the `PATH_VARS` list.

  `VERSION` is `${PROJECT_VERSION}` by default.

  `COMPATIBILITY` is either `AnyNewerVersion`, or `SameMajorVersion`, or
  `SameMinorVersion`, or `ExactVersion`.

  Set `ARCH_INDEPENDENT` for header-only libraries.
#]=============================================================================]
function(install_project_cmake_configs)
  __compact_parse_arguments(
    __options
      NO_SET_AND_CHECK_MACRO
      NO_CHECK_REQUIRED_COMPONENTS_MACRO
      ARCH_INDEPENDENT
    __values VERSION COMPATIBILITY
    __lists PATH_VARS
  )

  list(APPEND ARGS_PATH_VARS "INSTALL_CMAKE_DIR")

  set(no_set_and_check_macro "")
  if (ARGS_NO_SET_AND_CHECK_MACRO)
    set(no_set_and_check_macro "NO_SET_AND_CHECK_MACRO")
  endif()

  set(no_check_required_components_macro "")
  if (ARGS_NO_CHECK_REQUIRED_COMPONENTS_MACRO)
    set(no_check_required_components_macro "NO_CHECK_REQUIRED_COMPONENTS_MACRO")
  endif()

  set(config_file "${PACKAGE_NAME}Config.cmake")
  set(config_version_file "${PACKAGE_NAME}ConfigVersion.cmake")

  configure_package_config_file (
    "${PROJECT_SOURCE_DIR}/cmake/install/Config.cmake.in"
    "${PROJECT_BINARY_DIR}/${config_file}"
    INSTALL_DESTINATION "${INSTALL_CMAKE_DIR}"
    PATH_VARS ${ARGS_PATH_VARS}
    ${no_set_and_check_macro}
    ${no_check_required_components_macro}
  )

  if (NOT ARGS_VERSION)
    set(ARGS_VERSION "${PROJECT_VERSION}")
  endif()

  set(arch_independent "")
  if (ARGS_ARCH_INDEPENDENT)
    set(arch_independent "ARCH_INDEPENDENT")
  endif()

  write_basic_package_version_file(
    "${PROJECT_BINARY_DIR}/${config_version_file}"
    VERSION ${ARGS_VERSION}
    COMPATIBILITY ${ARGS_COMPATIBILITY}
    ${arch_independent}
  )

  set(configs_component "${namespace}_configs")
  install(FILES
      "${PROJECT_BINARY_DIR}/${config_file}"
      "${PROJECT_BINARY_DIR}/${config_version_file}"
    DESTINATION "${INSTALL_CMAKE_DIR}"
    COMPONENT ${configs_component}
  )
  add_component_target(${configs_component})
endfunction()

# Install the LICENSE file to `${INSTALL_LICENSE_DIR}`
macro(install_project_license)
  install(FILES
      "${PROJECT_SOURCE_DIR}/LICENSE"
    DESTINATION "${INSTALL_LICENSE_DIR}"
  )
endmacro()

#[=============================================================================[
  Install all headers (*.h, *.hh, *.h++, *.hpp, *.hxx, *.in, *.inc, and others
  described in the `PATTERNS` list) located in the `BASE_DIR`, export headers'
  directories (see the `generate_project_export_header` command), if any,
  and their subdirectories recursively to `${CMAKE_INSTALL_INCLUDEDIR}`.
  The directory structure in the `BASE_DIR` and export headers' directories, if
  any, is copied verbatim to the destination.

    install_project_headers([BASE_DIR <base_directory>]
                            [PATTERNS <patterns>...])

  By default, the `BASE_DIR` parameter is `${PROJECT_SOURCE_DIR}/include`.
  Set the install component to `${namespace}_headers`.
#]=============================================================================]
function(install_project_headers)
  __compact_parse_arguments(
    __values BASE_DIR
    __lists PATTERNS
  )

  if (NOT ARGS_BASE_DIR)
    set(ARGS_BASE_DIR "include")
  endif()

  if (NOT IS_ABSOLUTE "${ARGS_BASE_DIR}")
    set(ARGS_BASE_DIR "${PROJECT_SOURCE_DIR}/${ARGS_BASE_DIR}")
  endif()

  list(APPEND ARGS_PATTERNS
    "*.h"
    "*.hh"
    "*.h++"
    "*.hpp"
    "*.hxx"
    "*.in"
    "*.inc"
  )
  list(TRANSFORM ARGS_PATTERNS PREPEND "PATTERN;")

  set(export_headers_directories "")
  get_install_project_targets()
  foreach (target IN LISTS install_project_targets)
    get_project_target_property(export_header_dir ${target}
      PROJECT_PROPERTY EXPORT_HEADER_DIR
    )
    if (export_header_dir)
      list(APPEND export_headers_directories "${export_header_dir}/")
    endif()
  endforeach()

  set(headers_component "${namespace}_headers")
  install(DIRECTORY
      "${ARGS_BASE_DIR}/"
      ${export_headers_directories}
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
    COMPONENT ${headers_component}
    FILES_MATCHING ${ARGS_PATTERNS}
  )
  add_component_target(${headers_component})
endfunction()

#[=============================================================================[
  Install `targets` and install targets from the global project property
  `${NAMESPACE}_INSTALL_PROJECT_TARGETS` to specific destinations (see below).
  Generate and install `${PACKAGE_EXPORT_TARGET_NAME}.cmake` file.

    install_project_targets([TARGETS <targets>...] [HEADER_ONLY])

  `HEADER_ONLY` option is used to exclude installation of other artifacts. It
  actually doesn't make headers install, only exports the corresponding
  interface libraries as export targets.

  The specific destinations:
    RUNTIME DESTINATION: `${CMAKE_INSTALL_BINDIR}`
    LIBRARY DESTINATION: `${CMAKE_INSTALL_LIBDIR}`
    ARCHIVE DESTINATION: `${CMAKE_INSTALL_LIBDIR}`
    INCLUDES DESTINATION: `${CMAKE_INSTALL_INCLUDEDIR}`

  Set the install components to `${namespace}_runtime`,
  `${namespace}_development`, and `${namespace}_configs`.
#]=============================================================================]
function(install_project_targets)
  __compact_parse_arguments(
    __options HEADER_ONLY
    __lists TARGETS
  )

  set(target_list "")
  foreach (target IN LISTS ARGS_TARGETS)
    get_project_target_name(${target})
    if (NOT TARGET ${target})
      message(FATAL_ERROR "`${target}` is not a target.")
    endif()
    list(APPEND target_list ${target})
  endforeach()

  get_install_project_targets()
  list(APPEND target_list ${install_project_targets})

  if (NOT target_list)
    message(FATAL_ERROR "There are no targets to install.")
  endif()

  set(artifact_options "")
  if (NOT ARGS_HEADER_ONLY)
    set(runtime_component "${namespace}_runtime")
    set(development_component "${namespace}_development")
    list(APPEND artifact_options
      RUNTIME
        DESTINATION "${CMAKE_INSTALL_BINDIR}"
        COMPONENT ${runtime_component}
      LIBRARY
        DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        COMPONENT ${runtime_component}
        NAMELINK_COMPONENT ${development_component}
      ARCHIVE
        DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        COMPONENT ${development_component}
    )
    add_component_target(${runtime_component})
    add_component_target(${development_component})
  endif()

  install(TARGETS
      ${target_list}
    EXPORT "${PACKAGE_EXPORT_TARGET_NAME}"
    CONFIGURATIONS "Release"
    ${artifact_options}
    INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
  )

  set(configs_component "${namespace}_configs")
  install(EXPORT
      "${PACKAGE_EXPORT_TARGET_NAME}"
    NAMESPACE ${namespace}::
    DESTINATION "${INSTALL_CMAKE_DIR}"
    COMPONENT ${configs_component}
  )
  add_component_target(${configs_component})
endfunction()


############################## Auxiliary commands ##############################

#[=============================================================================[
  Add the custom target for an install ${component} to use it in build presets:

    {
      "name": "install_docs",
      ...
      "targets": "install_my_project_docs"
    }

  So the command below could run installation of the project documentation:

    cmake --build --preset install_docs

  If the custom target already exists, do nothing.
#]=============================================================================]
function(add_component_target component)
  if (NOT TARGET install_${component})
    add_custom_target(install_${component}
      COMMAND
        # `cmake --install` works only in 3.15+
        ${CMAKE_COMMAND} -DCOMPONENT=${component} -P "cmake_install.cmake"
      WORKING_DIRECTORY
        "${PROJECT_BINARY_DIR}"
      COMMENT
        "Installing ${component} component..."
    )
  endif()
endfunction()

function(append_install_project_target target)
  get_project_target_name(${target})
  set_global_project_property(APPEND
    PROPERTY
      ${NAMESPACE}_INSTALL_PROJECT_TARGETS
      ${target}
  )
endfunction()

macro(get_install_project_targets)
  get_global_project_property(install_project_targets
    PROPERTY
      ${NAMESPACE}_INSTALL_PROJECT_TARGETS
  )
endmacro()
