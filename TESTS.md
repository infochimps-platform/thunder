# Complete Set of Tests
            Test--->
                            (A) (B) (C) (D) (E)
   create                    X   X       X
   delete                    X 
   events                    X
   keypair create                X   X
   keypair delete                    X
   keypair fingerprints              I
   outputs                       X
   poll events               X   X       X
   stacks                                    X
   update                                X

                X = Does it explicitly
                I = Does it implicitly (e.g. through another method).

(not sure how to do tables in markdown)

Eventually, these should be automated, but in the mean time, these are run by 
hand.

Protip: You can change the title of terminal windows with:
```
  echo -en "\033]0;Test B\a"
```

## (AWS:A) Create and Delete Simple

Purpose:
* Ensure basic functionality for stack creation and deletion.

This is in the scope of "Create Simple with New Keypair" but that's longer

``` 
./thunder create foo ipa-foundation.rb ipa-foundation-parameters.yaml
./thunder poll events foo
```

Should finish with exit status 1. Do it again:

```
./thunder create foo ipa-foundation.rb ipa-foundation-parameters.yaml
```

Should catch an exception. Then, for the hell of it:

```
./thunder events foo
```

Now, dump it

```
./thunder delete foo
```


## (AWS:B) Thorough New Keypair Stack Creation Test

Purpose:
* Test the combination of keypair creation and stack creation and ensure that
  a newly-created keypair can actually be applied to a newly-created stack.

This tests key creation and its use with a new stack. 

```
./thunder keypair create zoo
chmod 700 ~/.ssh/zoo
```

create and wait

```
./thunder create goo ipa-foundation.rb ipa-foundation-parameters.yaml ipa-foundation-key-change.yaml
./thunder poll events goo -B
```

at the bell...

```
./thunder outputs goo|grep Control
```

and that's the ip of your Control machine

```
ssh -i ~/.ssh/zoo root@IP_OF_CONTROL_MACHINE
```

## (AWS:C) Keypair Subcommand

Purpose:
* Test all possible scenarios for keypair creation.

<private exists locally, public exists on AWS>
zoo does not exist. yet...

```
                                 #<0,0>
    ./thunder keypair create yoo #<1,1>
    ./thunder keypair delete yoo #<1,0>

    ./thunder keypair create yoo #<1,1>
    rm ~/.ssh/yoo                #<0,1>
    ./thunder keypair create yoo #<0,1>, should yell
    ./thunder keypair delete yoo #<0,0>
```


## (AWS:D) Update 

Purpose:
* Test the basic functionality of update.

Needs a different template here...
 
```
    ./thunder create hoo conditional.rb empty-params.json
    ./thunder poll events hoo
```

Wait until done. Then...

```
    ./thunder update hoo -r params-update.json
    ./thunder poll events hoo
```

Should UPDATE_COMPLETE.


## (AWS:E) Random Stuff

Purpose:
* Have one umbrella for testing miscellaneous tools that do not fall into the
  other tests. 

Tests all the stuff I didn't cover in the first four tests.

```
./thunder stacks
```

## (AWS:F) Update 2

Purpose:
* Ensure that parameters don't over write previously applied parameters during
  a stack update. 

This adds one instance to the stack, then another instance.  

```
    ./thunder create hoo conditional-2.rb param-L1.json
    ./thunder poll events hoo
```

Wait until done. Check that there is one instance. Then...

```
  ./thunder update hoo -r param-L2.json
  ./thunder poll events hoo
```

Check that there are two instances.

## (OS:A) Basics

Purpose:
* Test basic functionality of Openstack implementation. 

Create one instance on Openstack, get its outputs and whatnot. (Should be 
working as of 0.12.1).
```
./thunder create -o hoo one.yaml
./thunder events -o hoo
./thunder outputs -o hoo
```
Once you have outputs, do:
```
./thunder delete -o hoo
```

## (OS:B) Thorough New Keypair Stack Creation Test

Purpose:
* Test the combination of keypair creation and stack creation and ensure that
  a newly-created keypair can actually be applied to a newly-created stack.

This tests key creation and its use with a new stack.

This test is currently dysfunctional. one.yaml does not produce an output for
the control machine ip. 

```
./thunder keypair create -o zoo
chmod 700 ~/.ssh/zoo
```

create and wait

```
./thunder create goo -o one.yaml ipa-foundation-key-change.yaml
./thunder poll events goo -o -B
```

at the bell...

```
./thunder outputs -o goo|grep Control
```

and that's the ip of your Control machine

```
ssh -i ~/.ssh/zoo root@IP_OF_CONTROL_MACHINE
```

## (OS:C) Keypair Subcommand

Purpose:
* Test all possible scenarios for keypair creation.

<private exists locally, public exists on AWS>
zoo does not exist. yet...

```
                                    #<0,0>
    ./thunder keypair create -o yoo #<1,1>
    ./thunder keypair delete -o yoo #<1,0>

    ./thunder keypair create -o yoo #<1,1>
    rm ~/.ssh/yoo                   #<0,1>
    ./thunder keypair create -o yoo #<0,1>, should yell
    ./thunder keypair delete -o yoo #<0,0>
```


## (OS:D) Update 

Purpose:
* Test the basic functionality of update.

Note the differences between (AWS:D). It updates by posting a new version of
the template, not by changing a conditional. 

The default behavior--to use the original parameter settings--is broken, at 
least of the time of the creation of this test. To overcome this without 
posting parameters, use the -d setting. 

```
    ./thunder create -o hoo one.yaml
    ./thunder poll events -o hoo
```

Wait until done. Then...

```
    ./thunder update hoo -d -o two.yaml
    ./thunder poll events -o hoo
    ./thunder stacks -o
```

Should UPDATE_COMPLETE.

## (OS:E) Random Stuff

Purpose:
* Have one umbrella for testing miscellaneous tools that do not fall into the
  other tests. 

Tests all the stuff I didn't cover in the first four tests.

```
./thunder stacks -o
```
