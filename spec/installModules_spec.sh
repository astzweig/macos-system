Describe 'installModules'
  Include ./install.sh
  lop setoutput -l panic tostdout
  output=()
  runModule() { output=("$@") }

  It 'does nothing if modules array is empty'
    declare -A modulesToInstall=() moduleAnswers=()
    called=false
    generateModuleOptions() { called=true }
    When call installModules
    The output should eq ''
    The variable 'called' should eq 'false'
    The status should be success
  End

  It 'calls the module without options if answers is empty'
    declare -A moduleAnswers=()
    modulesToInstall=('/modules/my module')
    When call installModules
    The output should eq ''
    The variable 'output[1]' should eq '/modules/my module'
    The status should be success
  End

  It 'calls the module with given answers as options'
    declare -A moduleAnswers=('/modules/my module_name' 'hercules')
    modulesToInstall=('/modules/my module')
    When call installModules
    The output should eq ''
    The variable 'output' should eq '/modules/my module --name hercules'
    The variable 'output[1]' should eq '/modules/my module'
    The variable 'output[2]' should eq '--name'
    The variable 'output[3]' should eq 'hercules'
    The status should be success
  End
End
