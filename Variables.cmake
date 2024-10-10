#[=============================================================================[
  Project namespace, options, and cached variables
  ------------------------------------------------------------------------------
  This listfile is intended for editing existing cached variables or/and adding
  additional ones.
#]=============================================================================]

include_guard(GLOBAL)


# By default, it is `${PROJECT_NAME}` in uppercase/lowercase letters with
# underscores (for variables/targets accordingly).
# Otherwise, call the `define_project_namespace(<namespace>)` command.
define_project_namespace()

get_project_is_top_level()

############################### Project options ################################

#[=============================================================================[
  The root directory for the current listfile. Change it if you want to place
  all your auxiliary CMake-related files, in other directory (e.g., not "cmake",
  but "CMake" and so forth). It has to be the path relative to
  `${PROJECT_SOURCE_DIR}`.
#]=============================================================================]
project_cached_variable(ROOT_CMAKE_MODULES_DIR "cmake" INTERNAL
  "Directory for auxiliary CMake-related files"
)

#[=============================================================================[
  Allow to install all external dependencies locally (e.g. using `FetchContent`,
  or `ExternalProject` and downloading external sources into the binary
  directory), except to those that is not allowed explicitly by setting
  `${NAMESPACE}_INSTALL_<dependency-name>_LOCALLY`.
  `<dependency-name>` is just a name using by the `find_package` command.
#]=============================================================================]
project_option(INSTALL_EXTERNALS_LOCALLY "Install external dependencies locally" OFF)

#[=============================================================================[
  Prefer that the install rules are available if the project is on the top
  level, e.g. a regular project clone, building, and installing or using
  `ExternalProject`.
  Otherwise, neither when using `add_subdirectory` nor when using `FetchContent`
  is usually expected to generate install rules.
#]=============================================================================]
project_option(ENABLE_INSTALL "Enable the library installation"
  ON IF (PROJECT_IS_TOP_LEVEL AND (NOT CMAKE_SKIP_INSTALL_RULES))
)

#[=============================================================================[
  Set project-specific `BUILD_SHARED_LIBS`, so if an outer project that included
  this project as a subproject set its own `BUILD_SHARED_LIBS`, this won't have
  effect. The outer project can control this project's behavior regarding the
  type of libraries by setting `${NAMESPACE}_BUILD_SHARED_LIBS` before this
  project is included.
  See: https://cmake.org/cmake/help/latest/variable/BUILD_SHARED_LIBS.html
#]=============================================================================]
project_option(BUILD_SHARED_LIBS "Treat libraries as shared by default" OFF)

#[=============================================================================[
  Enable to make your library be used as a shared library or executable with
  plugins. Otherwise, set to `OFF`, e.g., if you develop a header-only library
  or reqular executable (without the `ENABLE_EXPORTS` property set).
  See: https://cmake.org/cmake/help/latest/module/GenerateExportHeader.html
#]=============================================================================]
project_option(ENABLE_EXPORT_HEADER "Enable creation of an export header" ON)
if (ENABLE_EXPORT_HEADER)
  include(GenerateExportHeader)
endif()

#[=============================================================================[
  Add the rpath, such as is set in `CMAKE_INSTALL_RPATH` below, to all installed
  shared libraries or executables. It may be useful for platforms that support
  rpath, when shared libraries or executables have dependencies that's
  distributed with the package itself and can be installed in a special place
  unknown for the dynamic loader.
  E.g., in Linux, the rpath set to `$ORIGIN` means that the dynamic loader will
  be looking for dependent shared libraries in the same place where the origin
  installed shared library or executable is located. You can add other paths,
  e.g., "\$ORIGIN/../lib".
  See: https://cmake.org/cmake/help/latest/prop_tgt/INSTALL_RPATH.html
#]=============================================================================]
project_option(ENABLE_INSTALL_RPATH "Enable adding rpath during installation" OFF)
if (ENABLE_INSTALL_RPATH AND ENABLE_INSTALL)
  if (APPLE)
    set(CMAKE_INSTALL_RPATH "@loader_path")
  elseif (UNIX)
    set(CMAKE_INSTALL_RPATH "\$ORIGIN")
  endif()
endif()

project_option(ENABLE_DOCS "Enable creating documentation" OFF)

# For small projects it is useless to enable `ccache`
project_option(ENABLE_CCACHE "Enable ccache" OFF)

#[=============================================================================[
  Enable treating the project's include directories as system via passing the
  `SYSTEM` option to the `target_include_directories` command inside the
  `project_target_include_directories` command. This may have effects such as
  suppressing warnings or skipping the contained headers in dependency
  calculations (see compiler documentation).
#]=============================================================================]
project_option(ENABLE_TREATING_INCLUDES_AS_SYSTEM
  "Use the `SYSTEM` option for the project's includes, compilers may disable warnings"
  ON IF (NOT PROJECT_IS_TOP_LEVEL)
)


############################## Developer options ###############################

project_option(ENABLE_DEVELOPER_MODE "Enable developer mode" OFF)

if ((NOT PROJECT_IS_TOP_LEVEL) AND ENABLE_DEVELOPER_MODE)
  message(AUTHOR_WARNING "Developer mode is intended for developers of \"${PROJECT_NAME}\".")
endif()

project_dev_option(ENABLE_TESTING "Enable testing")
project_cached_variable(TEST_DIR "tests" PATH "Testing directory")

project_dev_option(ENABLE_BENCHMARKING "Enable benchmarking")
project_dev_option(ENABLE_BENCHMARK_TOOLS "Enable benchmark tools")
project_cached_variable(BENCHMARK_DIR "benchmarks" PATH "Benchmarking directory")

project_dev_option(ENABLE_COVERAGE "Enable code coverage testing")

project_dev_option(ENABLE_FORMATTING "Enable code formatting")

project_dev_option(ENABLE_MEMORY_CHECKING "Enable memory checking tools")

# TODO: implement other developer options

if (ENABLE_DEVELOPER_MODE)
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE INTERNAL "Generate `compile_commands.json`")

  if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    create_symlink_to_compile_commands()
  endif()
endif()

project_option(ENABLE_PYTHON_VENV "Enable creating of Python virtual environment"
  # Specify other conditions, if any
  ON IF ENABLE_BENCHMARKING
)
project_cached_variable(PYTHON_VENV_DIR
  "${PROJECT_SOURCE_DIR}/.venv" PATH
  "Python virtual environment directory"
)

##################### Project non-boolean cached variables #####################

if (ENABLE_INSTALL)
  # Provides install directory variables as defined by the GNU Coding Standards.
  # See: https://www.gnu.org/prep/standards/html_node/Directory-Variables.html
  include(GNUInstallDirs)

  project_cached_variable(PACKAGE_NAME
    ${namespace} STRING
    "The package name used by the `find_package` command"
  )

  project_cached_variable(PACKAGE_EXPORT_TARGET_NAME
    "${PACKAGE_NAME}Targets" STRING
    "Name without extension of a file exporting targets for dependent projects"
  )

  project_cached_variable(INSTALL_CMAKE_DIR
    "${CMAKE_INSTALL_DATAROOTDIR}/${PACKAGE_NAME}/cmake" PATH
    "Installation directory for CMake configuration files"
  )

  project_cached_variable(INSTALL_LICENSE_DIR
    "${CMAKE_INSTALL_DATAROOTDIR}/${PACKAGE_NAME}" PATH
    "Installation directory for the LICENSE file"
  )

  if (ENABLE_DOCS)
    project_cached_variable(INSTALL_DOC_DIR
      "${CMAKE_INSTALL_DATAROOTDIR}/${PACKAGE_NAME}/doc" PATH
      "Installation directory for documentation"
    )
  endif()
endif(ENABLE_INSTALL)


############################ Variable init guard ###############################

# For internal use: prevent processing listfiles before including `Variables`
function(__variable_init_guard)
  # Do nothing, just check if this function exists
endfunction()
