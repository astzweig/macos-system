Describe 'isPlistBuddyInstalled'
  Include ./install.sh

  It 'returns success if PlistBuddy path exists' 
    test() { [ "$1" = "-x" ] && return }
    When call isPlistBuddyInstalled
    The output should eq ''
    The status should be success
  End

  It 'returns success if PlistBuddy is in PATH' 
    test() { [ "$1" = "-x" ] && return 1 }
    which() { [ "$1" = "PlistBuddy" ] && return }
    When call isPlistBuddyInstalled
    The output should eq ''
    The status should be success
  End

  It 'returns failure if PlistBuddy neither is in Path nor at usual path' 
    test() { [ "$1" = "-x" ] && return 1 }
    which() { [ "$1" = "PlistBuddy" ] && return 1 }
    When call isPlistBuddyInstalled
    The output should eq ''
    The status should be failure
  End
End
