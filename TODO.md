# To Do

* thor global options
  * add "config file" option

* parameter panic!
```
Hang on a minute! First you need to do some config file consolidation. Thunder can help a little bit. This is a more-or-less one time thing - you dont have to do this every time you launch.

```
launch-kickoff $ bundle exec thunder/thunder parameters foundation/builder.rb foundation/ipa-foundation-parameters.yaml  foudation/migrate-devipa-params.yaml  ~/migrate-devipa-local-params.yaml  > ~/builder_parameters.yaml
```

This will put a file in your home directory called builder_parameters that contains default and actual settings made by the stacks and parameters files. You may want to edit some parts of it by hand as it doesn't format long lines nicely. If you find that your config files are creeping out of control, you can use this thunder functionality to re-consolidated configuration. 
```
  * The version of parameters in openstack branch doesn't do this currently!

* aws S3
  * seems to be region sensitive
  * checkout SRP go

* burning amis
  * build into thunder as well
  * ebs-backed ONLY

* Get Test B working again?
  * a bit of a mess right now
  * no equivalent OS template for Test B

* poll events -o
  * make it also get the stack status, instead of just events?

* Migrate to thunder_cons
  * <strike>keypair fingerprints</strike> Removed altogether.

* cleaner event catching
  * no stack for delete, etc? Warn the user.

* dry run mode
  * put API into dry run mode.
  * make sure dry run mode is actually a dry run for API calls.
  * write an interface to dry run mode if there isn't one. '
  * no change of state
  * spit out what the template is creating
  * validate template

* add more verbose logging.

* poll events
  * OS: terminate condition

* events
  * cleaned up a bit, but still could use some work.

* dunce-cap testing
  * alternatively, look at the docs for api calls, and all errors that can be
    thrown, consider which ones to deal with, which ones not.
  * there are things about the error that can be caught and displayed generally

* write some test cases
  * integration tests
  * not have it communicate with external system
  * find mock libraries
