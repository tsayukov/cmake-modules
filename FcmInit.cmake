# Flexible CMake Modules
# ------------------------------------------------------------------------------
# Author: Pavel Tsayukov
# Repository: https://github.com/tsayukov/flexible-cmake-modules
# Distributed under the MIT License. See the accompanying file LICENSE or
# https://opensource.org/license/mit for details.
# ------------------------------------------------------------------------------
#
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# FOR COAUTHORS AND CONTRIBUTORS: fill in your name, contacts, and changes above
#
#[=================================================================[#github/wiki
  # Initialization of Flexible CMake Modules

  ## Table of Contents

  - [Usage](#Usage)
  - [Prefixes](#Prefixes)
    - [FCM_COMMAND_PREFIX_CONTROL](#FCM_COMMAND_PREFIX_CONTROL)
    - [FCM_PROJECT_COMMAND_PREFIX_CONTROL](#FCM_PROJECT_COMMAND_PREFIX_CONTROL)
    - [FCM_PROJECT_TARGET_PREFIX_CONTROL](#FCM_PROJECT_TARGET_PREFIX_CONTROL)
    - [FCM_PROJECT_CACHE_PREFIX_CONTROL](#FCM_PROJECT_CACHE_PREFIX_CONTROL)

  ## Usage

  ```cmake
  # CMakeLists.txt
  cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

  project(library-name CXX)

  include(cmake/FcmInit.cmake)
  ```

  You may adjust Flexible CMake Modules by setting control variables before
  including the `FcmInit` module. These control variables will be unset after
  the initialization, so they won't affect any sub-projects using FCM as well.
  Thus, be careful when using cached entries with the same names; they will be
  used by each `FcmInit` module if the normal variables are not defined.

  ## Prefixes

  The control variables that define a prefix for commands, targets, and cached
  entries must be set to a [proper][1] C identifier. Moreover, when the prefixes
  need to be read, they are checked, if they are still a proper C identifier,
  preventing execution of arbitrary code after configuring template CMake files.
  The check takes place using the `if` command, which cannot be overridden.

  An underscore will be added to each non-empty prefix. Note, that these control
  variables can be set to an empty string, except `FCM_COMMAND_PREFIX_CONTROL`.
  It is the same if there are no prefixes at all. It is not allowed to remove
  the prefix for FCM's commands, because then they will override some CMake
  commands.

  ### FCM_COMMAND_PREFIX_CONTROL

  The `FCM_COMMAND_PREFIX_CONTROL` variable defines a prefix for FCM's commands.
  By default, its value is `fcm`. To get the prefix, call
  the [`fcm_get_command_prefixes()`][9] command and use the `FCM_COMMAND_PREFIX`
  variable.

  ### FCM_PROJECT_COMMAND_PREFIX_CONTROL

  The `FCM_PROJECT_COMMAND_PREFIX_CONTROL` variable defines a prefix that
  is reserved for custom commands defined by the project's maintainers.
  By default, its value is a project name in lower case, converted to a proper
  C identifier. To get the prefix, call
  the [`fcm_get_command_prefixes()`][9] command and use
  the `FCM_PROJECT_COMMAND_PREFIX` variable. It can be used in template CMake
  files, e.g., `*.cmake.in`, to define commands and call them:

  ```cmake
  # CustomCommands.cmake.in
  function(@FCM_PROJECT_COMMAND_PREFIX@do_work)
    # do some work
  endfunction()

  function(@FCM_PROJECT_COMMAND_PREFIX@do_more_work)
    # do more work
    @FCM_PROJECT_COMMAND_PREFIX@do_work()
  endfunction()
  ```

  These template files can be configured and included by calling the
  [`fcm_include()`][2] command.

  ### FCM_PROJECT_TARGET_PREFIX_CONTROL

  The `FCM_PROJECT_TARGET_PREFIX_CONTROL` defines a prefix for project-specific
  targets that is set by calling the [`fcm_add_library()`][3]
  and [`fcm_add_executable()`][4]  commands.
  By default, its value is a project name in lower case, converted to a proper
  C identifier. To get the prefix, call
  the [`fcm_get_project_target_prefix()`][11] command and use
  the `FCM_PROJECT_TARGET_PREFIX` variable.

  ### FCM_PROJECT_CACHE_PREFIX_CONTROL

  The `FCM_PROJECT_CACHE_PREFIX_CONTROL` defines a prefix for project-specific
  cached entries that is set by calling the [`fcm_cache_entry()`][6],
  [`fcm_option()`][7], and [`fcm_dev_option()`][8] commands. By default,
  its value is a project name in upper case, converted to a proper C identifier.
  To get the prefix, call the [`fcm_get_project_cache_prefix()`][12] command
  and use the `FCM_PROJECT_CACHE_PREFIX` variable.

  [1]: https://cmake.org/cmake/help/latest/command/string.html#make-c-identifier
  [2]: https://github.com/tsayukov/flexible-cmake-modules/wiki/fcm_include
  [3]: https://github.com/tsayukov/flexible-cmake-modules/wiki/Project-specific-commands#fcm_add_library
  [4]: https://github.com/tsayukov/flexible-cmake-modules/wiki/Project-specific-commands#fcm_add_executable
  [6]: https://github.com/tsayukov/flexible-cmake-modules/wiki/Project-specific-commands#fcm_cache_entry
  [7]: https://github.com/tsayukov/flexible-cmake-modules/wiki/Project-specific-commands#fcm_option
  [8]: https://github.com/tsayukov/flexible-cmake-modules/wiki/Project-specific-commands#fcm_dev_option
  [9]: https://github.com/tsayukov/flexible-cmake-modules/wiki/Getters-of-FCM-Configuration-Variables#fcm_get_command_prefixes
  [11]: https://github.com/tsayukov/flexible-cmake-modules/wiki/Getters-of-FCM-Configuration-Variables#fcm_get_project_target_prefix
  [12]: https://github.com/tsayukov/flexible-cmake-modules/wiki/Getters-of-FCM-Configuration-Variables#fcm_get_project_cache_prefix
#]=================================================================]#github/wiki

cmake_policy(PUSH)
cmake_policy(VERSION 3.14)


# Set the next major version after the release
set(__FCM_MAJOR_VERSION__ "0")
set(__FCM_RELATIVE_CACHE_DIR__ "FcmCache/v${__FCM_MAJOR_VERSION__}")
unset(__FCM_MAJOR_VERSION__)


if (NOT PROJECT_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  message(FATAL_ERROR ${__FCM_DEBUG_CATCH_FATAL_ERROR__}
    "Flexible CMake Modules must be included in a listfile "
    "that sets the project's name after the `project()` call."
  )
  cmake_policy(POP)
  return()
endif()


if (DEFINED FCM_COMMAND_PREFIX_CONTROL AND FCM_COMMAND_PREFIX_CONTROL STREQUAL "")
  message(FATAL_ERROR ${__FCM_DEBUG_CATCH_FATAL_ERROR__}
    "`FCM_COMMAND_PREFIX_CONTROL` must be non-empty."
  )
  cmake_policy(POP)
  return()
endif()


# `FCM_PREFIXES` the cache file's structure

set(__FCM_PREFIXES_VARIABLES__
  "FCM_PROJECT_TARGET_PREFIX"
  "FCM_PROJECT_CACHE_PREFIX"
)
set(__FCM_PREFIXES_LENGTH__ 4)

string(MAKE_C_IDENTIFIER "${PROJECT_NAME}" __project_name_id)

set(__FCM_PROJECT_TARGET_PREFIX_INDEX__ 1)
string(TOLOWER "${__project_name_id}" __FCM_PROJECT_TARGET_PREFIX_DEFAULT__)
set(__FCM_PROJECT_CACHE_PREFIX_INDEX__ 3)
string(TOUPPER "${__project_name_id}" __FCM_PROJECT_CACHE_PREFIX_DEFAULT__)

unset(__project_name_id)

# `FCM_TEMPLATE_PREFIXES` the cache file's structure

set(__FCM_TEMPLATE_PREFIXES_VARIABLES__
  "FCM_COMMAND_PREFIX"
  "FCM_PROJECT_COMMAND_PREFIX"
)
set(__FCM_TEMPLATE_PREFIXES_LENGTH__ 4)

set(__FCM_COMMAND_PREFIX_INDEX__ 1)
set(__FCM_COMMAND_PREFIX_DEFAULT__ "fcm")
set(__FCM_PROJECT_COMMAND_PREFIX_INDEX__ 3)
set(__FCM_PROJECT_COMMAND_PREFIX_DEFAULT__ "${__FCM_PROJECT_TARGET_PREFIX_DEFAULT__}")

# FCM origins

set(__FCM_NO_ORIGIN__ 0)
set(__FCM_ORIGIN_THIS_PROJECT__ 1)
set(__FCM_ORIGIN_MESSAGE_${__FCM_ORIGIN_THIS_PROJECT__}__
  "(in the \"${PROJECT_NAME}\" project)"
)
set(__FCM_ORIGIN_OUTER_PROJECT__ 2)
set(__FCM_ORIGIN_THIS_PROJECT_FROM_OUTER_PROJECT__ 3)
set(__FCM_ORIGIN_MESSAGE_${__FCM_ORIGIN_THIS_PROJECT_FROM_OUTER_PROJECT__}__
  "(in the \"${PROJECT_NAME}\" project by the outer project)"
)

# Check/Init FCM cache files

set(__FCM_CACHE_DIR__ "${PROJECT_BINARY_DIR}/${__FCM_RELATIVE_CACHE_DIR__}")

foreach (file IN ITEMS
  "FCM_TEMPLATE_PREFIXES"
  "FCM_PREFIXES"
)
  foreach (variable IN LISTS __${file}_VARIABLES__)
    set(__${variable}_OVERRIDDEN__ OFF)

    if (DEFINED CACHE{${variable}_CONTROL})
      message(WARNING
        "Found the `${variable}_CONTROL` cached entry "
        "with the value \"$CACHE{${variable}_CONTROL}\"; "
        "make sure that Flexible CMake Modules are adjusted via the normal variable."
      )
    endif()

    if (NOT DEFINED ${variable}_CONTROL)
      set(${variable}_CONTROL "${__${variable}_DEFAULT__}")
    endif()

    if (NOT ${variable}_CONTROL STREQUAL "")
      if (NOT ${variable}_CONTROL MATCHES "^[_A-Za-z][_0-9A-Za-z]*$")
        message(FATAL_ERROR ${__FCM_DEBUG_CATCH_FATAL_ERROR__}
          "`${variable}_CONTROL` must be a proper C identifier, "
          "but its value is \"${${variable}_CONTROL}\"."
        )
        cmake_policy(POP)
        return()
      endif()
      string(CONCAT ${variable}_CONTROL "${${variable}_CONTROL}" "_")
    endif()
  endforeach()

  set(__override OFF)

  if (NOT EXISTS "${__FCM_CACHE_DIR__}/${file}")
    set(__override ON)
    foreach (variable IN LISTS __${file}_VARIABLES__)
      set(__${variable}_OVERRIDDEN__ ON)
      set(__${variable}_ORIGIN__ "${__FCM_ORIGIN_THIS_PROJECT__}")
    endforeach()
  else()
    file(READ "${__FCM_CACHE_DIR__}/${file}" __content)

    list(LENGTH __content __content_length)
    if (NOT __content_length EQUAL __${file}_LENGTH__)
      message(FATAL_ERROR ${__FCM_DEBUG_CATCH_FATAL_ERROR__}
        "FCM cache file \"${file}\" contains "
        "the wrong amount of elements: ${__content_length}. "
        "Expected length: ${__${file}_LENGTH__}."
      )
      cmake_policy(POP)
      return()
    endif()
    unset(__content_length)

    foreach (variable IN LISTS __${file}_VARIABLES__)
      math(EXPR __position "${__${variable}_INDEX__} - 1")
      list(GET __content ${__position} __${variable}_ORIGIN__)
      unset(__position)

      list(GET __content ${__${variable}_INDEX__} __${variable}_VALUE__)

      if (__${variable}_ORIGIN__ EQUAL __FCM_NO_ORIGIN__)
        set(__override ON)
        set(__${variable}_OVERRIDDEN__ ON)
        set(__${variable}_ORIGIN__ "${__FCM_ORIGIN_THIS_PROJECT__}")
      elseif (__${variable}_ORIGIN__ EQUAL __FCM_ORIGIN_THIS_PROJECT__)
        if (NOT ${variable}_CONTROL STREQUAL __${variable}_VALUE__)
          set(__override ON)
          set(__${variable}_OVERRIDDEN__ ON)
        endif()
      elseif (__${variable}_ORIGIN__ EQUAL __FCM_ORIGIN_OUTER_PROJECT__)
        set(__override ON)
        set(__${variable}_OVERRIDDEN__ ON)
        set(${variable}_CONTROL "${__${variable}_VALUE__}")
        set(__${variable}_ORIGIN__ "${__FCM_ORIGIN_THIS_PROJECT_FROM_OUTER_PROJECT__}")
      elseif (__${variable}_ORIGIN__ EQUAL __FCM_ORIGIN_THIS_PROJECT_FROM_OUTER_PROJECT__)
        set(${variable}_CONTROL "${__${variable}_VALUE__}")
      else()
        message(FATAL_ERROR ${__FCM_DEBUG_CATCH_FATAL_ERROR__}
          "Unknown FCM origin in FCM cache file \"${file}\": "
          "\"${__${variable}_ORIGIN__}\""
        )
        cmake_policy(POP)
        return()
      endif()

      unset(__${variable}_VALUE__)
    endforeach()
  endif()

  foreach (variable IN LISTS __${file}_VARIABLES__)
    if (NOT ${variable}_CONTROL STREQUAL ""
          AND NOT ${variable}_CONTROL MATCHES "^[_A-Za-z][_0-9A-Za-z]*$")
      message(FATAL_ERROR ${__FCM_DEBUG_CATCH_FATAL_ERROR__}
        "`${variable}` must be a proper C identifier, "
        "but its value is \"${${variable}_CONTROL}\"."
      )
      cmake_policy(POP)
      return()
    endif()
  endforeach()

  if (NOT __override)
    set_property(GLOBAL PROPERTY __FCM_RECONFIGURE_TEMPLATES__ OFF)
  else()
    set(__content "")
    foreach (variable IN LISTS __${file}_VARIABLES__)
      list(APPEND __content "${__${variable}_ORIGIN__}" "${${variable}_CONTROL}")
    endforeach()

    file(WRITE "${__FCM_CACHE_DIR__}/${file}" "${__content}")

    set_property(GLOBAL PROPERTY __FCM_RECONFIGURE_TEMPLATES__ ON)
  endif()

  unset(__override)

  foreach (variable IN LISTS __${file}_VARIABLES__)
    if (__${variable}_OVERRIDDEN__)
      message(STATUS
        "FCM: set ${variable}: \"${${variable}_CONTROL}\" "
        "${__FCM_ORIGIN_MESSAGE_${__${variable}_ORIGIN__}__}"
      )
    endif()

    set(${variable} "${${variable}_CONTROL}")

    unset(${variable}_CONTROL)
    unset(__${variable}_DEFAULT__)
    unset(__${variable}_ORIGIN__)
    unset(__${variable}_OVERRIDDEN__)
  endforeach()

  unset(__content)
  unset(__${file}_VARIABLES__)
endforeach()

unset(__FCM_NO_ORIGIN__)
unset(__FCM_ORIGIN_MESSAGE_${__FCM_ORIGIN_THIS_PROJECT__}__)
unset(__FCM_ORIGIN_THIS_PROJECT__)
unset(__FCM_ORIGIN_OUTER_PROJECT__)
unset(__FCM_ORIGIN_MESSAGE_${__FCM_ORIGIN_THIS_PROJECT_FROM_OUTER_PROJECT__}__)
unset(__FCM_ORIGIN_THIS_PROJECT_FROM_OUTER_PROJECT__)
unset(__FCM_CACHE_DIR__)


if (FCM_COMMAND_PREFIX STREQUAL "")
  message(FATAL_ERROR ${__FCM_DEBUG_CATCH_FATAL_ERROR__}
    "`FCM_COMMAND_PREFIX` must be non-empty."
  )
  cmake_policy(POP)
  return()
endif()

# Removing CMakeCache.txt causes reconfiguring all templates
# E.g., via `--fresh`
set(__FCM_FORCE_RECONFIGURE_TEMPLATES__ ON CACHE BOOL "")
if ($CACHE{__FCM_FORCE_RECONFIGURE_TEMPLATES__})
  set_property(GLOBAL PROPERTY __FCM_RECONFIGURE_TEMPLATES__ ON)
  set(__FCM_FORCE_RECONFIGURE_TEMPLATES__ OFF CACHE BOOL "" FORCE)
endif()
mark_as_advanced(__FCM_FORCE_RECONFIGURE_TEMPLATES__)


set(${FCM_PROJECT_CACHE_PREFIX}_CMAKE_MODULE_PATH
  "${CMAKE_CURRENT_LIST_DIR}"
  "${CMAKE_CURRENT_LIST_DIR}/modules"
  CACHE STRING
  "Search paths for CMake modules"
)
set(CMAKE_MODULE_PATH ${${FCM_PROJECT_CACHE_PREFIX}_CMAKE_MODULE_PATH})


if (__FCM_SKIP_INCLUDING__ OR __FCM_SKIP_INCLUDING_AND_FAIL__)
  if (__FCM_SKIP_INCLUDING_AND_FAIL__)
    message(FATAL_ERROR ${__FCM_DEBUG_CATCH_FATAL_ERROR__}
      "`__FCM_SKIP_INCLUDING_AND_FAIL__` is turned on."
    )
  endif()

  cmake_policy(POP)
  return()
endif()


file(RELATIVE_PATH __FCM_TEMPLATE_DIR__
  "${PROJECT_SOURCE_DIR}"
  "${CMAKE_CURRENT_LIST_DIR}"
)
foreach (module IN ITEMS
  common/FcmConfigVariables
  common/ParseArgs
  FcmInclude
  Common
)
  configure_file(
    "${PROJECT_SOURCE_DIR}/${__FCM_TEMPLATE_DIR__}/${module}.cmake.in"
    "${PROJECT_BINARY_DIR}/${__FCM_TEMPLATE_DIR__}/${module}.cmake"
    @ONLY
  )
  include("${PROJECT_BINARY_DIR}/${__FCM_TEMPLATE_DIR__}/${module}.cmake")
endforeach()

unset(__FCM_TEMPLATE_DIR__)

unset(__FCM_PREFIXES_LENGTH__)
unset(__FCM_PROJECT_TARGET_PREFIX_INDEX__)
unset(__FCM_PROJECT_CACHE_PREFIX_INDEX__)

unset(__FCM_TEMPLATE_PREFIXES_LENGTH__)
unset(__FCM_COMMAND_PREFIX_INDEX__)
unset(__FCM_PROJECT_COMMAND_PREFIX_INDEX__)

unset(__FCM_RELATIVE_CACHE_DIR__)

cmake_policy(POP)
