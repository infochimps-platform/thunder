Feature: Thunder
  In order to access cloud tools from the command line
  As a developer
  I want to be able to use the Thunder CLI tool

  Scenario: Thunder Help
    When I run `thunder`
    Then the exit status should be 0
    And  the output should match:
    """
    Commands:
      thunder config .*$
      thunder config_import .*$
      thunder help \[COMMAND\] .*$
      thunder keypair \[COMMAND\].*$
      thunder poll \[COMMAND\] .*$
      thunder remote_file \[COMMAND\] .*$
      thunder sherpa \[COMMAND\] .*$
      thunder stack \[COMMAND\] .*$

    Options:
      -S, \[--config-section=CONFIG_SECTION\] .*$
      -c, \[--config-file=CONFIG_FILE\] .*$
      -o, \[--openstack\], \[--no-openstack\] .*$
      -a, \[--aws\], \[--no-aws\] .*$
    """

  Scenario: Thunder Config
    When I run `thunder config -c thunder.yaml` interactively
    And  I type "aws"
    And  I type "10"
    And  I type "abc"
    And  I type "123"
    And  I type "us-east-1"
    And  I type "whatever.com"
    And  I type "johnny"
    And  I type "shazam"
    And  I type "password"
    And  I type "none"
    Then the output should contain:
    """
    Thunder Config
    If you don't know (or don't care) the values, leave them blank.
    If you want to use the old value, leave it blank.
    Stack flavor:  [aws, openstack] (aws) aws
    Poll events timeout (in seconds): 10
    aws_access_key_id:  abc
    aws_secret_access_key:  123
    region:  us-east-1
    openstack_auth_url:  whatever.com
    openstack_username:  johnny
    openstack_tenant:  shazam
    openstack_api_key:  password
    connection_options:  none
    Done. Further changes can be made at thunder.yaml
    """
    And  the file "thunder.yaml" should contain:
    """
    default:
      aws_access_key_id: abc
      aws_secret_access_key: '123'
      region: us-east-1
      openstack_auth_url: whatever.com
      openstack_username: johnny
      openstack_tenant: shazam
      openstack_api_key: password
      connection_options: none
      flavor: aws
      poll_events_timeout: 10
    """
    
  Scenario: Thunder Config Import AWS
    Given a file named "aws.config" with:
    """
    [default]
    aws_access_key_id = abc
    aws_secret_access_key = 123
    output = json
    region = us-east-1
    """
    When  I run `thunder config_import aws aws.config -c thunder.yaml`
    Then  the output should contain "Config updated with native aws"
    And   the file "thunder.yaml" should contain:
    """
    default:
      aws_access_key_id: abc
      aws_secret_access_key: '123'
      region: us-east-1
      openstack_auth_url: 
      openstack_username: 
      openstack_tenant: 
      openstack_api_key: 
      connection_options: 
      flavor: aws
      output: json
    """

  Scenario: Thunder Config Import Openstack
    Given I set the environment variables to:
    | variable       | value        |
    | os_auth_url    | whatever.com |
    | os_username    | johnny       |
    | os_tenant_name | shazam       |
    | os_password    | password     |
    | os_region_name | blue         |
    When  I run `thunder config_import openstack -c tmp/thunder.yaml`
    Then  the output should contain "Config updated with native openstack"
    And   the file "tmp/thunder.yaml" should contain:
    """
    default:
      aws_access_key_id: 
      aws_secret_access_key: 
      region: 
      openstack_auth_url: whatever.com
      openstack_username: johnny
      openstack_tenant: shazam
      openstack_api_key: password
      connection_options: 
      flavor: openstack
      openstack_region_name: blue
    """

  Scenario: Thunder Keypair Help
    When I run `thunder keypair`
    Then the output should match:
    """
    keypair commands:
      thunder keypair create name .*$
      thunder keypair delete name .*$
      thunder keypair help \[COMMAND\] .*$
    """

  @aws @keypair
  Scenario: Thunder Keypair Create
    When I run `thunder keypair create example example.pub`
    Then the output should contain "Generating new private and public keys called example"
    And  the keypair "example" should exist

