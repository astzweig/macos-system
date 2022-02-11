Describe 'generateModuleOptions'
  Include ./install.sh

  It 'does nothing if answers array is empty'
    declare -A answers=()
    moduleOptions=()
    When call generateModuleOptions
    The output should eq ''
    The variable 'moduleOptions' should eq ''
    The status should be success
  End

  It 'does nothing if answers does not contain module answers'
    declare -A answers=('some-module_name' 'answer')
    mod='module/my-module'
    moduleOptions=()
    When call generateModuleOptions
    The output should eq ''
    The variable 'moduleOptions' should eq ''
    The status should be success
  End

  It 'prefixes single char option names with a dash'
    declare -A answers=('mymodule_n' 'my name')
    mod='mymodule'
    moduleOptions=()
    When call generateModuleOptions
    The output should eq ''
    The variable 'moduleOptions' should eq '-n my name'
    The status should be success
  End

  It 'does not prefix single char option name with dash if it is already a dash'
    declare -A answers=('mymodule_-' 'my name')
    mod='mymodule'
    moduleOptions=()
    When call generateModuleOptions
    The output should eq ''
    The variable 'moduleOptions' should eq '- my name'
    The status should be success
  End

  It 'prefixes multi char option names with double dash'
    declare -A answers=('mymodule_your-name' 'my name')
    mod='mymodule'
    moduleOptions=()
    When call generateModuleOptions
    The output should eq ''
    The variable 'moduleOptions' should eq '--your-name my name'
    The status should be success
  End

  It 'does not prefix multi char option names with double dash if it starts with a dash'
    declare -A answers=('mymodule_-your-name' 'my name')
    mod='mymodule'
    moduleOptions=()
    When call generateModuleOptions
    The output should eq ''
    The variable 'moduleOptions' should eq '-your-name my name'
    The status should be success
  End

  It 'works with modules that contains slashes'
    declare -A answers=('/some/dir/mymodule_your-name' 'my name')
    mod='/some/dir/mymodule'
    moduleOptions=()
    When call generateModuleOptions
    The output should eq ''
    The variable 'moduleOptions' should eq '--your-name my name'
    The status should be success
  End

  It 'works with modules that contains spaces'
    declare -A answers=('/some/dir with spaces/mymodule with spaces_your-name' 'my name')
    mod='/some/dir with spaces/mymodule with spaces'
    moduleOptions=()
    When call generateModuleOptions
    The output should eq ''
    The variable 'moduleOptions' should eq '--your-name my name'
    The status should be success
  End
End
