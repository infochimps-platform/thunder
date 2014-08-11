# Thunder

Thor + Cloud = Thunder   
Thunder is a Thor-implemented set of tools for cloud formation.

## Setup Tips

Run
```
$ ./thunder config
```
Supply your credentials as prompted. The output is at ~/.thunder/config . It is
yaml, so adjustments can be made easily without running the wizard again. 
Any empty string values will preserve the previous value.  

* Can be run as an executable:

```
$ ./thunder                # gives a list of commands
$ ./thunder help [COMMAND] # gives description of command
```

## Basic Launch Steps (AWS)

I recommend changing to a different key pair name, especially if there's a 
chance that you'll conflict with someone. 

You'll need ipa-foundation.rb and ipa-foundation-parameters.yaml. If there's
a chance of conflict, you ought to also use a different key pair name from 
"zoo." You'll have to both use different values in the commands below and
use a modified ipa-foundation-key-change.yaml.

Create keypair

```
$ ./thunder keypair create zoo
```

Change permissions on keypair

```
$ chmod 700 ~/.ssh/zoo
```

Create and wait

```
$ ./thunder create foo ../foundation/ipa-foundation.rb ../foundation/ipa-foundation-parameters.yaml 
$ ./thunder poll events foo -B
```

At the bell...

```
$ ./thunder outputs foo | grep Control
```

...and that's the ip of your Control machine

```
$ ssh -i ~/.ssh/zoo root@IP_OF_CONTROL_MACHINE
```

## Switching Between OpenStack and AWS on the fly. 
./thunder config lets you choose whether you run OpenStack or AWS by default.
If you want to change between them, use the -o or -a option, respectively. 
