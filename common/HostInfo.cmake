#[=============================================================================[
  Author: Pavel Tsayukov
  Distributed under the MIT License. See accompanying file LICENSE or
  https://opensource.org/license/mit for details.
  ------------------------------------------------------------------------------
  Host information
  ------------------------------------------------------------------------------
  Commands:
  - get_n_physical_cores
  - get_n_logical_cores
#]=============================================================================]

include_guard(GLOBAL)


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
