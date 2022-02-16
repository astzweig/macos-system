Describe 'configureLogging'
  Include ./modules/lib.sh
  args=()
  lop() { args=("$@") }
  setup() { args=() }
  BeforeEach setup

  It 'configures lop with standard args'
    When call configureLogging
    The variable 'args[3]' should eq 'info'
    The variable 'args[4]' should eq 'tostdout'
  End

  It 'configures lop output mode'
    logfile="/some/path with spaces/to/file.txt"
    When call configureLogging
    The variable 'args[3]' should eq 'info'
    The variable 'args[4]' should eq "${logfile}"
  End

  It 'configures lop log level'
    verbose=true
    When call configureLogging
    The variable 'args[3]' should eq 'debug'
    The variable 'args[4]' should eq 'tostdout'
  End

  It 'configures lop output mode and log level'
    logfile="/some/path with spaces/to/file.txt"
    verbose=true
    When call configureLogging
    The variable 'args[3]' should eq 'debug'
    The variable 'args[4]' should eq "${logfile}"
  End
End
