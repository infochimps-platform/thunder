Feature: Thunder
  In order to access cloud tools from the command line
  As a developer
  I want to be able to use the Thunder CLI tool

  Scenario: Thunder Help
    When I run `thunder`
    Then the output should match:
    """
    app commands:
      thunder config .*$
      thunder config_import .*$
      thunder help .*$
      thunder keypair .*$
      thunder poll .*$
      thunder remote_file .*$
      thunder sherpa .*$
      thunder stack .*$
    """
