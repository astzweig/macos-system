Describe 'filterModules'
  Include ./install.sh
  It 'returns all modules if no module arg is given'
    allModules=(module1 module2 'module3 with space') modulesToInstall=()
    When call filterModules
    The variable modulesToInstall should eq 'module1 module2 module3 with space'
    The status should be success
  End

  It 'returns only mentioned modules'
    allModules=(module1 module2 'module3 with space') modulesToInstall=()
    module=('module3 with space' module2)
    When call filterModules
    The variable modulesToInstall should eq 'module2 module3 with space'
    The status should be success
  End

  It 'matches modules by ending pattern'
    allModules=(dir1/module1 dir2/module1 /dir/module1/'module3 with space') modulesToInstall=()
    module=(module1)
    When call filterModules
    The variable modulesToInstall should eq 'dir1/module1 dir2/module1'
    The status should be success
  End

  It 'returns only not mentioned modules if inversed'
    allModules=(module1 module2 'module3 with space') modulesToInstall=()
    module=('module3 with space' module1)
    inverse=true
    When call filterModules
    The variable modulesToInstall should eq 'module2'
    The status should be success
  End
End
