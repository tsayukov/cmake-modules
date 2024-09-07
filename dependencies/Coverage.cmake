#[=============================================================================[
  Author: Pavel Tsayukov
  Distributed under the MIT License. See accompanying file LICENSE or
  https://opensource.org/license/mit for details.
  ------------------------------------------------------------------------------
  Code coverage
  ------------------------------------------------------------------------------
  Enable the `${NAMESPACE}_ENABLE_DEVELOPER_MODE` or
  `${NAMESPACE}_ENABLE_COVERAGE` project option to turn code coverage on.
  See `../Variables.cmake` for details.
#]=============================================================================]

include_guard(GLOBAL)


enable_if(ENABLE_COVERAGE)

# TODO: implement
