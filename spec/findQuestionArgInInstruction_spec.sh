Describe 'findQuestionArgInInstruction'
  Include ./install.sh
  instructions=('somearg:somevalue' 'default:one' 'choose from:blue,light green,red')

  It 'finds nothing if no arg name given'
    argValue=''
    When call findQuestionArgInInstruction
    The variable argValue should eq ''
    The status should be success
  End

  It 'finds nothing if arg name does not exist'
    argValue=''
    When call findQuestionArgInInstruction 'arg name that does not exist'
    The variable argValue should eq ''
    The status should be failure
  End

  It 'finds nothing if instructions is empty'
    instructions=()
    argValue=''
    When call findQuestionArgInInstruction 'some arg name'
    The variable argValue should eq ''
    The status should be failure
  End

  It 'finds arg value if instructions contains arg as first item'
    argValue=''
    When call findQuestionArgInInstruction 'somearg'
    The variable argValue should eq 'somevalue'
    The status should be success
  End

  It 'finds arg value if instructions contains arg among other items'
    argValue=''
    When call findQuestionArgInInstruction 'choose from'
    The variable argValue should eq 'blue,light green,red'
    The status should be success
  End
End
