Describe 'generateConfigKeysFromQuestionID'
  Include ./install.sh

  It 'does nothing if given no arguments' 
    declare -A configkeys=()
    When call generateConfigKeysFromQuestionID ''
    The output should eq ''
    The variable 'configkeys' should eq ''
    The status should be success
  End

  It 'does nothing if question id is empty' 
    declare configkeys=()
    When call generateConfigKeysFromQuestionID 'somemod' ''
    The output should eq ''
    The variable 'configkeys' should eq ''
    The status should be success
  End

  It 'generates key when given module name and question id'
    declare configkeys=()
    When call generateConfigKeysFromQuestionID 'somemod' 'somekey'
    The output should eq ''
    The variable 'configkeys' should eq 'somemod questions somekey'
    The status should be success
  End

  It 'replaces minus with underscore'
    declare configkeys=()
    When call generateConfigKeysFromQuestionID 'some-mod' 'somekey'
    The output should eq ''
    The variable 'configkeys' should eq 'some_mod questions somekey'
    The status should be success
  End

  It 'replaces multiple minus with single underscore'
    declare configkeys=()
    When call generateConfigKeysFromQuestionID 'some---mod' 'so--mekey'
    The output should eq ''
    The variable 'configkeys' should eq 'some_mod questions so_mekey'
    The status should be success
  End

  It 'replaces underscores at the begin and end of string'
    declare configkeys=()
    When call generateConfigKeysFromQuestionID '--some-mod' '--somekey-'
    The output should eq ''
    The variable 'configkeys' should eq 'some_mod questions somekey'
    The status should be success
  End

  It 'removes all chars but [A-Za-z_]'
    declare configkeys=()
    When call generateConfigKeysFromQuestionID '*some≠{mod' '?`somekey'
    The output should eq ''
    The variable 'configkeys' should eq 'somemod questions somekey'
    The status should be success
  End
End
