Describe 'getFilteredModules'
  Include ./install.sh
  It 'returns all modules if no module arg is given'
    allModules=(module1 module2)
    When call getFilteredModules
    The output should eq 'module1 module2'
    The status should be success
  End

  It 'returns only mentioned modules'
    allModules=(module1 module2 module3)
    module=(module3 module2)
    When call getFilteredModules
    The output should eq 'module2 module3'
    The status should be success
  End

  It 'returns only not mentioned modules if inversed'
    allModules=(module1 module2 module3)
    module=(module3 module1)
    inverse=true
    When call getFilteredModules
    The output should eq 'module2'
    The status should be success
  End
End
