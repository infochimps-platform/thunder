# Changelog

##Version 0.14.2
* JSON/YAML output options for:
  * outputs
  * stacks
  * <strike>events</strike>
    * A wee-bit more difficult. Is it useful? Probably not?
  * <strike>poll events</strike>
    * A wee-bit more difficult. Is it useful? Probably not?

* Made config stack mostly flavor agnostic:
  * Added thunder config
  * If ~/.thunder/config does not exist, it is written to use AWS by default.
  * Added -a option to all commands with a -o option.

* Broke parameter filtering out of load_parameters
  * into filter_parameters, for both AWS and OS

* display_events moved to thunder_cons

* added config_import and associated methods in thunder_cons

* whitespace strip in Stack::load_config

* (Tests passed |AWS| : A,B,C,D,E,F)
* (Tests passed |OS|  : A,C)


##Version 0.14.1
* Removed all calls to Thor::say from thunder_cons
* Added OS tests.
* Tweaked existing tests.
* (Tests passed |AWS| : A,C,D,E,F)
* (Tests passed |OS|  : A,C,D,E)
* !!! Test AWS:B is still failing! !!!


##Version 0.14
* Continued refactoring aws and openstack into a common interface.
  * Moved:
    * keypair create/delete - just the connection components, AWS only
    * update
    * events
    * poll events
    * parameters

* Prepared for OpenStack:
  * poll events - sorta. termination condition is poorly defined
    * keypair create
    * keypair delete
    * ??? update ??? (see TODO.md for details)


##Version 0.13
* Refactoring aws and openstack into a common interface.
  * Moved huge portions of code to thunder_cons.rb
  * working for AWS/OS:
    * thunder stacks
    * thunder create
    * thunder delete
    * thunder outputs
* Removed unreferrenced methods:
  * event_string


##Version 0.12.3
* Modified lambdas in load_parameters.
  * Had to change them for OpenStack anyway.
  * More readable.

##Version 0.12.2
* Fixed create
* Updated TESTS.md
  * added test (G)
* Updated README.md
  * Openstack-related config stuff.
* Numerous outputs cleaned up.
* poll events migrated to Openstack
* Fixed update for AWS.
  * Implicit class dependencies fixed. 
  * OS functionality is unclear. I need a template to test it with. 
* Clarified purposes of the tests.
* (Tests passed: A,C,D,E,F,G)
* !!! Test B is failing !!!

##Version 0.12.1
* Migrated OS output to Formatador in:
  * stacks
  * outputs
* config actually reads from a file now:
  * ~/.openstack/config
  * similar fashion to AWS

##Version 0.12.0
* This begins the Openstack Implementation branch
* Added self.orch
  * Connects to Orchestration/heat
* -o option in create, delete, <strike>update</strike> (broken), 
  outputs, stacks.
* create, delete, outputs, events, stacks are ready for Openstack.
* Early refactoring to allow Openstack compliance for update
  * it's gonna get ugly before it's gonna get better.


##Version 0.11.4
* <strike>Environment variables previously only read if AWS_ACCESS_KEY_ID 
  is set.</strike>
  * <strike>Fixed to check for each variable, made a bit more abstract.</strike>
  * See comments in config_aws.
* Typos in Test B
  * ipa-foundation-zookey-test.yaml changed to ipa-foundation-key-change.yaml
    * Real filename change.
  * ipa-foundation-parameters.json changed to ipa-foundation-parameters.yaml
    * I was just tab completing and overlooked this.
* Typos in Test C
    * Deleted wrong key.
* (Tests passed: C, D, E) 

##Version 0.11.3
* README.md changes--basic launch process clarified, enumerated.
* Added ipa-foundation-key-change.yaml

##Version 0.11.2
* event_strings are generated with one method now Stack::event_string

##Version 0.11.1
* update behavior was corrupting values, fixed.
* added Test (F) for update.
* (Tests passed: A, B, C, D, E, F)

##Version 0.11.0
* Changes in "plural_hashload"
  * load_parameters gets previous outputs, not previous parameters, which is
    needed for parameters. In fact, it needs both. So there's some radical 
    refactoring under the hood. Previous functionality should remain.
* TESTS migrated to markdown (mostly)
* "keypair create name" was not posting public keys, a change likely from 
  yesterday's after the merge collision. This was fixed.
* (Tests passed: A, B, C, D, E)

##Version 0.10.0
* "update": added merge behavior with previous parameter settings
* "update": added start-with-defaults option -d

##Version 0.9.3
* small documentation changes

##Version 0.9.2
* indentation incorrect in "poll events"
* fixed Poll::bell (crashed with "say")
* "delete" now warns if the target stack does not exist; issues delete request
  if it does.

##Version 0.9.1
* poll events fixed during: 
  * updates (works by default)
  * deletes (-d option to exit with SUCCESS when the stack vanishes)
* formalized set of tests
  * see TESTS
  * will be automating these soon
* Partially reverted move from "puts" to "Thor::say"
  * broken in "fingerprints"
  * crummy patch--works, but unclear why the problem happened originally

## Version 0.9

* "events" now sorts the instance variables before dumping them.
* Moved "puts" to "Thor::say"
* To "thunder poll events", added terminal (-B) vs event bells (-b)
* Major improvements to update:
  * no longer a static and public method--just public. It's no longer being called from create and is no longer necessary.
  * Split loader into two, because it actually does two things, and these are done different in create and update.
  * update -r uses existing template
* changes made to create. verified ok.

## Version 0.8

* Added "keypair fingerprint"
* something weird is going on, likely aws's key encryption
* Changed behavior of "keypair create"
  * syntax is the same
  * performs a lot more useful stuff in the right conditions that will freak out when something's wrong.
  * see "./thunder keypair help create"

## Version 0.7

* Stack events array reversed
  * oldest events were printed out last, so they were seen first.
* Removed auto-update functionality from create
* Added: poll events name
* c.f. poll-stack-events

## Version 0.6.1

* keypairs not deleted locally by keypair delete

## Version 0.6

* Added keypair subcommand for creating and posting AWS keypairs.

## Version 0.5

* Events had an uncorrected copyo in description.
* Adding automatic key-pair creation/uploading
  * still in the works
* Region changed to be read from config
  * was previously hard-coded as "us-west-1"

## Version 0.4
* Bugs introduced in "update" by positional parameters--these are fixed.
* Documentation cleaned up
  * -P params removed from documentation.
* Added "stacks"
  * dumps out existing stacks and their status.
* Added "outputs"
  * dumps out outputs from stack
* Added "events"
  * dumps out events from stack
* Removed Herobrine.

## Version 0.3
* Parameters are positional.

## Version 0.2
* Fixed .rb support for templates
  * requires cfndsl
  * I've done this two different ways. Probably should narrow to one.
* Added update
  * refactored some common loading functions to "load" (but not everything, unfortunately).
  * behavior may be unpredictable. The behavior for blank values still needs to be verified.

## Version 0.1

* It works. It's an executable.
* I merged the old Utils class with Stack to get it working as an executable.
* I don't think thor likes having multiple classes.
