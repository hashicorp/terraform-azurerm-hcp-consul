schema_version = 1

project {
  license        = "MPL-2.0"
  copyright_year = 2022

  # (OPTIONAL) A list of globs that should not have copyright/license headers.
  # Supports doublestar glob patterns for more flexibility in defining which
  # files or folders should be ignored
  header_ignore = [
    "hcp-ui-templates/aks-existing-vnet/main.tf",
    "hcp-ui-templates/aks/main.tf",
    "hcp-ui-templates/vm-existing-vnet/main.tf",
    "hcp-ui-templates/vm/main.tf",
    "test/hcp/testdata/vm-existing-vnet.golden",
    "test/hcp/testdata/vm.golden",
  ]
}
