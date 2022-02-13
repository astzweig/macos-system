# macOS System
Scripts to align a macOS system to Astzweig system configuration.

## Install

```zsh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/astzweig/macos-system/main/bootstrap.sh)"
```

## What it does
1. Run all setup from a temporary directory and delete it in the end

## Process
1. `install.sh` queries all modules for their required information
1. The modules print their required information to stdout using the format as described below.
1. `install.sh` parses those informations and tries to read them from a configuration file.
1. If the configuration file does not have those informations, it asks the user.
1. `install.sh` then runs the modules with their required informations passed in as parameter values.

## Required Information Format
Modules must print their required information to stdout if they're called with
`show-questions` command. Required information are all information the module
might want to ask the user in order to configure some aspect of the system.

### Schema
The general schema is:

```zsh
#(i|p|c|s): <PARAMETER NAME>=<QUESTION> [# (<arg name>: <arg value>) [(; <arg name>: <arg value>)...]]
s: --highlight-color=What color shall your system highlight color be? # choose from: blue,red,light green;
p: --user-password=What color shall your system highlight color be?
```
The letter at the beginning is the question type:

| Question type | Description | Arguments |
| ------------- | ----------- | --------- |
| i (info) | A question where the user has no restrictions on input | - |
| p (password) | A question where the user input is not printed to standard output. | - |
| c (confirm) | A yes/no question where the user is allowed to answer yes or no. | - |
| s (select) | A list of choices where the user can select one using numbers. | `choose from`: a comma separated list of possible select values. |

`<PARAMETER NAME>` is the the parameter name, that will receive the user answer
when the module is called. Single char parameter names will be prefixed with a
single dash while multi char parameter names will be prefixed by double dashes.
E.g. the parameter name `s` becomes `-s <user response>` on module call, while
the parameter name `highlight-color` becomes `--highlight-color <user response>`.
`<QUESTION>` must contain any punctuation you want to show.

[^zshlib-askUser]: Currently supported: info, password, confirm, choose. They map to [zshlib/askUser][zshlib-overview] commands.
[zshlib-overview]: https://github.com/astzweig/zshlib#whats-included
