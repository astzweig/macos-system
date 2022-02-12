Describe 'askNecessaryQuestions'
  Include ./install.sh

  It 'sets config app name'
    appname=''
    config() { [ "$1" = setappname ] && appname="$2" }
    When call askNecessaryQuestions
    The variable 'appname' should eq 'de.astzweig.macos.system-setup'
  End

  It 'sets config file path'
    configpath=''
    config() { [ "$1" = setconfigfile ] && configpath="$2" }
    config_only='/my/file/path'
    When call askNecessaryQuestions
    The variable 'configpath' should eq '/my/file/path'
  End

  It 'writes config to given file'
    declare -A answers
    config_only="`mktemp`"
    modulesToInstall=('mymodule')
    populateQuestionsWithModuleRequiredInformation() { questions+=('my-question' $'What is my question?\ninfo') }
    readConfig() { config read mymodule questions my_question }
    Data 'myanswer'
    When call askNecessaryQuestions
    The variable answers should eq 'myanswer'
    The result of function readConfig should eq 'myanswer'
  End
End
