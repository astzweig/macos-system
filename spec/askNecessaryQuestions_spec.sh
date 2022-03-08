Describe 'askNecessaryQuestions'
  Include ./install.sh
  lop setoutput -l panic tostdout
  askUserModuleQuestions() {}

  It 'sets config app name'
    appname=''
    config() { [ "$1" = setappname ] && appname="$2" }
    When call askNecessaryQuestions
    The variable 'appname' should eq 'de.astzweig.macos.system-setup'
  End

  It 'sets config file path in config_only mode'
    configpath=''
    config() { [ "$1" = setconfigfile ] && configpath="$2" }
    config_only='/my/file/path'
    When call askNecessaryQuestions
    The variable 'configpath' should eq '/my/file/path'
  End

  It 'sets config file path in if -c option is given'
    configpath=''
    config() { [ "$1" = setconfigfile ] && configpath="$2" }
    config='/my/file/path'
    When call askNecessaryQuestions
    The variable 'configpath' should eq '/my/file/path'
  End
End
