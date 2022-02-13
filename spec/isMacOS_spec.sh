Describe 'isMacOS'
  Include ./install.sh
  uname() {  [ "${1}" = -s ] && echo Darwin }

  It 'returns failure if sw_vers is not installed'
    sw_vers() { echo "zsh: command not found: sw_vers" >&2; return 127 }
    When call isMacOS
    The output should eq ''
    The status should be failure
  End

  It 'returns failure if os version is below 10.13'
    sw_vers() { echo "1.1" }
    When call isMacOS
    The output should eq ''
    The status should be failure
  End

  It 'returns success if os version is 10.13'
    sw_vers() { echo "10.13" }
    When call isMacOS
    The output should eq ''
    The status should be success
  End

  It 'returns success if os version is above 10.13'
    sw_vers() { echo "17.04" }
    When call isMacOS
    The output should eq ''
    The status should be success
  End

  It 'returns failure if kernel name is not Darwin'
    sw_vers() { echo "10.13" }
    uname() {  [ "${1}" = -s ] && echo Linux }
    When call isMacOS
    The output should eq ''
    The status should be failure
  End
End
